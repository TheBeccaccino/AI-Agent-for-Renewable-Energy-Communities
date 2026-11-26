"""Addestramento e valutazione delle baseline locali di CERBot.

La baseline traditional usa TF-IDF di parole e caratteri seguito da una
regressione logistica. La baseline semantic usa gli embedding di un encoder
MiniLM preaddestrato seguito da una regressione logistica. L'encoder viene
usato come estrattore fisso di caratteristiche durante questa procedura.

Tutti i fit usano il dataset ChatGPT. Le prestazioni su ChatGPT sono ottenute
con cinque fold out-of-fold. Il fit finale usa tutto ChatGPT e produce il
classificatore applicato ai tre dataset esterni.

Per seguire il percorso principale leggere corpus(), pipeline(), encode()
e infine run(). Router serve a ricaricare un modello salvato per l'inferenza.
"""

import argparse
import hashlib
import importlib.metadata as metadata
import json
import platform
from pathlib import Path
from time import perf_counter

import joblib
import numpy as np
import pandas as pd
import psutil
from sklearn.base import clone
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import accuracy_score, f1_score
from sklearn.model_selection import StratifiedGroupKFold
from sklearn.pipeline import FeatureUnion, Pipeline
from threadpoolctl import threadpool_limits

# Il seme rende riproducibile la costruzione dei fold e le operazioni che lo usano.
SEED = 20261120
# Identita e revisione attese per lo snapshot scaricato da fetch_encoder.py.
MODEL = "sentence-transformers/paraphrase-multilingual-MiniLM-L12-v2"
REV = "e8f8c211226b894fcb81acc59f3b34ba3efd5f42"
# Uno stesso messaggio compare in diversi run storici. Questa coppia identifica
# l'esempio di corpus e permette di eliminare le copie prima dell'addestramento.
KEY = ["dataset", "sample_id"]
FIELDS = KEY + ["text", "true_label"]
SETS = ["ChatGPT", "Claude", "Grok", "DeepSeek"]


def corpus(path):
    """Legge il CSV, controlla gli esempi e separa sviluppo e test esterni.

    path indica il CSV con dataset, sample_id, text e true_label. Le copie
    identiche vengono eliminate. ID discordanti, campi vuoti e label diverse
    associate allo stesso testo normalizzato provocano un errore.

    Restituisce due DataFrame. dev contiene ChatGPT e la colonna norm usata
    per raggruppare i duplicati nella cross-validation. ext contiene gli altri
    dataset e seen_in_dev, che segnala testi gia presenti nello sviluppo.
    La normalizzazione riguarda raggruppamenti e controlli. Il classificatore
    riceve il contenuto della colonna text.
    """
    raw = pd.read_csv(path, usecols=FIELDS, dtype=str, keep_default_na=False)
    d = raw[FIELDS].drop_duplicates().copy()
    if d.duplicated(KEY).any() or d[FIELDS].eq("").any().any():
        raise ValueError("Each dataset/sample_id must have one non-empty text and label")
    if set(d.dataset) != set(SETS):
        raise ValueError("Expected four named corpus partitions")
    # strip elimina gli spazi esterni. casefold uniforma maiuscole e minuscole.
    d["norm"] = d.text.str.strip().str.casefold()
    if d.groupby("norm").true_label.nunique().max() > 1:
        raise ValueError("Same normalized text has conflicting ground truth")
    dev = d[d.dataset == "ChatGPT"].copy()
    ext = d[d.dataset != "ChatGPT"].copy()
    dev = dev.sort_values("sample_id", key=lambda s: s.astype(int)).reset_index(drop=True)
    ext["seen_in_dev"] = ext.norm.isin(dev.norm)
    if dev.true_label.nunique() != 19 or not set(ext.true_label) <= set(dev.true_label):
        raise ValueError("Expected the same known 19 target intents")
    return dev, ext.reset_index(drop=True)


def pipeline(kind):
    """Costruisce un classificatore ancora da addestrare.

    Per semantic l'input previsto e una matrice di embedding gia calcolati.
    La pipeline contiene quindi la sola regressione logistica multiclasse.
    Per traditional l'input e una sequenza di testi e la pipeline aggiunge
    TF-IDF su parole di 1-2 termini e gruppi di 3-5 caratteri.

    Restituisce una Pipeline scikit-learn. C=1 e prefissato. max_iter=1000
    limita le iterazioni dell'ottimizzatore lbfgs. Il fit avviene in run().
    """
    lr = LogisticRegression(C=1.0, solver="lbfgs", max_iter=1000, random_state=SEED)
    if kind == "semantic":
        return Pipeline([("classifier", lr)])
    feat = FeatureUnion(
        [
            ("word", TfidfVectorizer(ngram_range=(1, 2), sublinear_tf=True)),
            ("char", TfidfVectorizer(analyzer="char_wb", ngram_range=(3, 5), sublinear_tf=True)),
        ]
    )
    return Pipeline([("features", feat), ("classifier", lr)])


def get_encoder(path):
    """Carica dalla cartella path l'encoder SentenceTransformer su CPU.

    I pesi devono essere gia presenti in locale. Per lo snapshot MiniLM
    fornito, il modello produce embedding di 384 componenti. Il caricamento
    prepara il modello per l'estrazione degli embedding effettuata da encode().
    """
    from sentence_transformers import SentenceTransformer

    return SentenceTransformer(str(path), device="cpu", local_files_only=True)


def encode(encoder, texts):
    """Converte i testi in una matrice numerica con un embedding per riga.

    encoder e il modello preaddestrato caricato da get_encoder(). texts e una
    sequenza di messaggi. Per il MiniLM scelto l'output ha forma N per 384.
    Ogni vettore e normalizzato a norma L2 unitaria. batch_size=32 stabilisce
    quanti testi vengono codificati insieme. Questa chiamata esegue inferenza.
    """
    return encoder.encode(
        list(texts), batch_size=32, normalize_embeddings=True, show_progress_bar=False
    )


class Router:
    """Classificatore salvato, caricabile una volta e riutilizzabile sui messaggi.

    Conserva in memoria regressione logistica ed eventuale encoder semantico.
    E usato dal benchmark Python e dal bridge cerbot_classify_local.m.
    """

    def __init__(self, directory):
        """Carica classifier.joblib e l'eventuale encoder dalla cartella modello.

        metadata.json identifica la baseline semantic. Per questa baseline
        viene caricata anche la sottocartella encoder. La baseline traditional
        conserva nel joblib sia i vettorizzatori TF-IDF sia il classificatore.
        Il costruttore inizializza gli attributi clf ed encoder.
        """
        root = Path(directory)
        self.clf = joblib.load(root / "classifier.joblib")
        self.encoder = (
            get_encoder(root / "encoder")
            if (root / "metadata.json").is_file()
            and json.loads((root / "metadata.json").read_text(encoding="utf-8"))["kind"]
            == "semantic"
            else None
        )

    def classify(self, message):
        """Classifica un messaggio e restituisce la coppia (label, probabilita).

        Il percorso semantico calcola prima l'embedding. Il percorso lessicale
        passa il testo alla pipeline TF-IDF salvata. predict_proba restituisce
        una probabilita per ciascuna classe. La label scelta ha la probabilita
        massima e il secondo valore restituito e quella stessa probabilita.
        Lo score deriva dalla regressione logistica, senza calibrazione separata.
        """
        x = encode(self.encoder, [str(message)]) if self.encoder is not None else [str(message)]
        probs = self.clf.predict_proba(x)[0]
        i = int(probs.argmax())
        return str(self.clf.classes_[i]), float(probs[i])


def score(y, p, labels):
    """Riassume le predizioni con conteggi, accuracy e macro-F1 percentuali.

    y contiene le label vere, p quelle predette e labels l'elenco delle classi
    da includere nella media. Restituisce un dizionario con n, correct,
    accuracy_pct e macro_f1_pct. Il denominatore nullo di F1 viene trattato
    come zero. Nell'esperimento labels contiene tutte le 19 classi target.
    """
    return {
        "n": len(y),
        "correct": int(np.sum(np.asarray(y) == np.asarray(p))),
        "accuracy_pct": 100 * accuracy_score(y, p),
        "macro_f1_pct": 100 * f1_score(y, p, labels=labels, average="macro", zero_division=0),
    }


def run(kind, source, out, encoder_dir):
    """Esegue cross-validation, fit finale e valutazione dei dataset esterni.

    kind seleziona traditional oppure semantic. source e il CSV preparato.
    out e la cartella degli output. encoder_dir indica lo snapshot locale
    dell'encoder e viene usato per la baseline semantic.

    La procedura costruisce cinque modelli per le predizioni out-of-fold di
    ChatGPT. Un sesto fit su tutto ChatGPT produce il modello finale salvato
    in model/. Quel modello classifica Claude, Grok e DeepSeek.

    Gli output comprendono il classificatore, l'encoder quando previsto,
    metadata.json, development_oof.csv, external_predictions.csv, scores.csv
    e runtime.json. La funzione scrive su disco e stampa un riepilogo.
    """
    # Preparazione delle partizioni e della cartella del modello.
    dev, ext = corpus(source)
    labels = sorted(dev.true_label.unique())
    out = Path(out)
    out.mkdir(exist_ok=True, parents=True)
    root = out / "model"
    root.mkdir(exist_ok=True)
    enc = None
    clock = perf_counter()
    proc = psutil.Process()
    rss0 = proc.memory_info().rss
    if kind == "semantic":
        if not encoder_dir:
            raise ValueError("Supply a local snapshot with --encoder-dir; see README")
        enc = get_encoder(encoder_dir)
    # Nel caso semantico gli embedding si calcolano una volta con l'encoder
    # fisso. Nel caso TF-IDF si mantengono i testi e ogni fold adatta da zero
    # i propri vettorizzatori sul relativo sottoinsieme di training.
    y = dev.true_label.to_numpy()
    X = encode(enc, dev.text) if enc is not None else dev.text.to_numpy()
    prepare_s = perf_counter() - clock
    estimator = pipeline(kind)
    pred = np.empty(len(y), object)
    # La stratificazione bilancia le classi per quanto consentito dai gruppi.
    # I testi uguali dopo normalizzazione appartengono allo stesso gruppo.
    folds = StratifiedGroupKFold(n_splits=5, shuffle=True, random_state=SEED)
    clock = perf_counter()
    for tr, va in folds.split(X, y, groups=dev.norm):
        # clone crea una pipeline nuova. Le label del fold va vengono usate
        # per valutare le sue predizioni dopo il fit sui soli indici tr.
        fitted = clone(estimator).fit(X[tr], y[tr])
        pred[va] = fitted.predict(X[va])
    cv_s = perf_counter() - clock
    clock = perf_counter()
    # Fit finale su tutti gli esempi ChatGPT. Qui si apprendono i coefficienti
    # della regressione logistica usata successivamente sui dataset esterni.
    estimator.fit(X, y)
    fit_s = perf_counter() - clock
    joblib.dump(estimator, root / "classifier.joblib", compress=3)
    if enc is not None:
        enc.save(str(root / "encoder"))
    # Versioni, parametri, hash e provenienza permettono di documentare il run.
    versions = {
        p: metadata.version(p)
        for p in ["scikit-learn", "numpy", "scipy", "joblib", "pandas", "psutil"]
    }
    if enc is not None:
        versions["sentence-transformers"] = metadata.version("sentence-transformers")
    meta = dict(
        kind=kind,
        seed=SEED,
        development="ChatGPT",
        C=1.0,
        labels=labels,
        versions=versions,
        platform=platform.platform(),
        python=platform.python_version(),
        source_sha256=hashlib.sha256(Path(source).read_bytes()).hexdigest(),
        dev_embeddings_or_setup_s=prepare_s,
        validation_s=cv_s,
        final_fit_s=fit_s,
        encoder_dir=str(encoder_dir) if enc is not None else None,
        encoder_expected_model=MODEL if enc is not None else None,
        encoder_expected_revision=REV if enc is not None else None,
    )
    if enc is not None:
        marker = Path(encoder_dir) / "cerbot_source.json"
        meta["encoder_source_record"] = (
            json.loads(marker.read_text(encoding="utf-8")) if marker.is_file() else None
        )
        encoder_root = root / "encoder"
        meta["encoder_file_sha256"] = {}
        for weight in sorted(encoder_root.rglob("*")):
            if weight.is_file():
                with weight.open("rb") as handle:
                    meta["encoder_file_sha256"][weight.relative_to(encoder_root).as_posix()] = (
                        hashlib.file_digest(handle, "sha256").hexdigest()
                    )
    (root / "metadata.json").write_text(json.dumps(meta, indent=2), encoding="utf-8")
    # Per lo sviluppo si salvano le predizioni del fold escluso, cosi ogni
    # esempio viene valutato da un classificatore addestrato sugli altri fold.
    devout = dev[FIELDS].copy()
    devout["pred_label"] = pred
    devout.to_csv(out / "development_oof.csv", index=False)
    clock = perf_counter()
    # Si ricarica il modello dal disco per separare il tempo di caricamento
    # dai tempi caldi misurati dopo un messaggio di riscaldamento.
    router = Router(root)
    cold_s = perf_counter() - clock
    router.classify("Messaggio di prova")
    rows = []
    for row in ext.itertuples():
        # Il tempo include embedding e classificazione. La misura e interna
        # al runtime Python. Il bridge MATLAB viene misurato da un altro script.
        clock = perf_counter()
        guess, confidence = router.classify(row.text)
        latency = perf_counter() - clock
        rows.append(
            (
                row.dataset,
                row.sample_id,
                row.true_label,
                guess,
                row.seen_in_dev,
                latency,
                confidence,
            )
        )
    results = pd.DataFrame(
        rows, columns=KEY + ["true_label", "pred_label", "seen_in_dev", "warm_core_s", "score"]
    )
    results.to_csv(out / "external_predictions.csv", index=False)
    # Oltre ai singoli dataset, si riportano aggregati e il sottoinsieme
    # DeepSeek con testi assenti dallo sviluppo dopo normalizzazione.
    groups = {ds: results.dataset == ds for ds in ["Claude", "Grok", "DeepSeek"]}
    groups["Claude + Grok"] = results.dataset.isin(["Claude", "Grok"])
    groups["3 archive sets"] = np.ones(len(results), bool)
    groups["DeepSeek unseen text"] = results.dataset.eq("DeepSeek") & ~results.seen_in_dev
    summary = [{"cohort": "ChatGPT out-of-fold", **score(y, pred, labels)}]
    for name, mask in groups.items():
        s = results[mask]
        summary.append(
            {
                "cohort": name,
                **score(s.true_label, s.pred_label, labels),
                "warm_median_ms": 1000 * s.warm_core_s.median(),
                "warm_p95_ms": 1000 * s.warm_core_s.quantile(0.95),
            }
        )
    pd.DataFrame(summary).to_csv(out / "scores.csv", index=False)
    m = dict(
        cold_load_s=cold_s,
        model_bytes=sum(p.stat().st_size for p in root.rglob("*") if p.is_file()),
        run_rss_start_bytes=rss0,
        run_rss_end_bytes=proc.memory_info().rss,
        remote_inference_calls=0,
        timing="CPU, one warm-up, one message at a time, Python core, no MATLAB or network; RSS includes training process; not peak model memory.",
    )
    (out / "runtime.json").write_text(json.dumps(m, indent=2), encoding="utf-8")
    print(pd.DataFrame(summary).to_string(index=False))


if __name__ == "__main__":
    # Questo blocco viene eseguito quando il file e avviato dalla riga di
    # comando. Quando il modulo e importato, sono disponibili le funzioni.
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--data", required=True)
    p.add_argument("--kind", choices=["traditional", "semantic"], required=True)
    p.add_argument("--out", required=True)
    p.add_argument("--encoder-dir")
    a = p.parse_args()
    with threadpool_limits(limits=1):
        run(a.kind, a.data, a.out, a.encoder_dir)
