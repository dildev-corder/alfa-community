"""Build the Alfa Community machine-learning final report as a polished PDF."""

from __future__ import annotations

import json
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
import pandas as pd
from reportlab.lib import colors
from reportlab.lib.enums import TA_CENTER, TA_JUSTIFY, TA_LEFT
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import cm
from reportlab.platypus import (
    BaseDocTemplate,
    Frame,
    Image,
    KeepTogether,
    PageBreak,
    PageTemplate,
    Paragraph,
    Spacer,
    Table,
    TableStyle,
)

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "output" / "pdf"
FIG = OUT / "figures"
PDF = OUT / "Alfa_Community_ML_Final_Report.pdf"
BLUE = colors.HexColor("#1769AA")
NAVY = colors.HexColor("#123C5A")
GREEN = colors.HexColor("#1D6B49")
PALE = colors.HexColor("#EAF3EA")
GREY = colors.HexColor("#515A61")


def make_figures() -> dict[str, Path]:
    FIG.mkdir(parents=True, exist_ok=True)
    figures: dict[str, Path] = {}

    flood = pd.read_csv(ROOT / "datasets/flood/flood.csv")
    landslide = pd.read_csv(ROOT / "datasets/landslide/landslide.csv")

    plt.figure(figsize=(8.8, 4.2))
    for idx, (name, frame) in enumerate((("Flood", flood), ("Landslide", landslide)), 1):
        ax = plt.subplot(1, 2, idx)
        counts = frame.risk_label.value_counts().sort_index()
        ax.bar(["Low", "Medium", "High"], counts, color=["#70AD47", "#FFC000", "#C00000"])
        ax.set_title(f"{name} risk class distribution")
        ax.set_ylabel("Records")
        ax.spines[["top", "right"]].set_visible(False)
    plt.tight_layout()
    figures["risk_classes"] = FIG / "risk_class_distribution.png"
    plt.savefig(figures["risk_classes"], dpi=180)
    plt.close()

    corr = landslide.corr(numeric_only=True)
    plt.figure(figsize=(6.2, 4.8))
    plt.imshow(corr, cmap="Blues", vmin=-1, vmax=1)
    plt.colorbar(label="Correlation")
    labels = ["Rainfall", "Slope", "Soil moisture", "Risk"]
    plt.xticks(range(4), labels, rotation=30, ha="right")
    plt.yticks(range(4), labels)
    for y in range(4):
        for x in range(4):
            plt.text(x, y, f"{corr.iloc[y, x]:.2f}", ha="center", va="center")
    plt.title("Landslide feature correlation matrix")
    plt.tight_layout()
    figures["landslide_corr"] = FIG / "landslide_correlation.png"
    plt.savefig(figures["landslide_corr"], dpi=180)
    plt.close()

    garbage = {
        "Battery": 756, "Biological": 699, "Cardboard": 1411,
        "Clothes": 1892, "Glass": 1736, "Metal": 930, "Paper": 1336,
        "Plastic": 1597, "Shoes": 1449, "Trash": 453,
    }
    plt.figure(figsize=(9, 4.4))
    plt.bar(garbage.keys(), garbage.values(), color="#1D6B49")
    plt.xticks(rotation=35, ha="right")
    plt.ylabel("Images")
    plt.title("Garbage dataset class distribution")
    plt.grid(axis="y", alpha=.2)
    plt.tight_layout()
    figures["garbage"] = FIG / "garbage_class_distribution.png"
    plt.savefig(figures["garbage"], dpi=180)
    plt.close()

    results = pd.read_csv(ROOT / "runs/detect/runs/elephant/alfa_elephant_cpu_5e/results.csv")
    plt.figure(figsize=(8.8, 4.2))
    plt.plot(results.epoch, results["metrics/precision(B)"], marker="o", label="Precision")
    plt.plot(results.epoch, results["metrics/recall(B)"], marker="o", label="Recall")
    plt.plot(results.epoch, results["metrics/mAP50(B)"], marker="o", label="mAP@0.50")
    plt.plot(results.epoch, results["metrics/mAP50-95(B)"], marker="o", label="mAP@0.50:0.95")
    plt.ylim(0, 1)
    plt.xlabel("Epoch")
    plt.ylabel("Metric")
    plt.title("Elephant detector validation metrics")
    plt.legend(ncol=2)
    plt.grid(alpha=.2)
    plt.tight_layout()
    figures["elephant_metrics"] = FIG / "elephant_training_metrics.png"
    plt.savefig(figures["elephant_metrics"], dpi=180)
    plt.close()

    return figures


class ReportDoc(BaseDocTemplate):
    def __init__(self, filename: str):
        super().__init__(filename, pagesize=A4, leftMargin=2.3*cm, rightMargin=2.3*cm,
                         topMargin=2.1*cm, bottomMargin=2.0*cm,
                         title="Alfa Community Machine Learning Final Report",
                         author="Alfa Community Project Team")
        frame = Frame(self.leftMargin, self.bottomMargin, self.width, self.height, id="normal")
        self.addPageTemplates(PageTemplate(id="report", frames=[frame], onPage=self._page))

    @staticmethod
    def _page(canvas, doc):
        if doc.page > 1:
            canvas.saveState()
            canvas.setStrokeColor(colors.HexColor("#D8E2E7"))
            canvas.line(2.3*cm, A4[1]-1.45*cm, A4[0]-2.3*cm, A4[1]-1.45*cm)
            canvas.setFont("Helvetica", 8)
            canvas.setFillColor(GREY)
            canvas.drawString(2.3*cm, A4[1]-1.2*cm, "ALFA COMMUNITY  |  MACHINE LEARNING FINAL REPORT")
            canvas.drawCentredString(A4[0]/2, 1.1*cm, str(doc.page))
            canvas.restoreState()


def styles():
    s = getSampleStyleSheet()
    s.add(ParagraphStyle(name="CoverSmall", parent=s["Normal"], fontName="Times-Bold",
                         fontSize=14, leading=19, alignment=TA_CENTER, spaceAfter=7))
    s.add(ParagraphStyle(name="CoverTitle", parent=s["Title"], fontName="Times-Bold",
                         fontSize=24, leading=31, alignment=TA_CENTER, textColor=NAVY, spaceAfter=18))
    s.add(ParagraphStyle(name="H1x", parent=s["Heading1"], fontName="Times-Roman",
                         fontSize=20, leading=25, textColor=BLUE, spaceBefore=10, spaceAfter=13))
    s.add(ParagraphStyle(name="H2x", parent=s["Heading2"], fontName="Times-Roman",
                         fontSize=15, leading=19, textColor=BLUE, spaceBefore=9, spaceAfter=8))
    s.add(ParagraphStyle(name="Bodyx", parent=s["BodyText"], fontName="Times-Roman",
                         fontSize=10.5, leading=17, textColor=GREY, alignment=TA_JUSTIFY, spaceAfter=8))
    s.add(ParagraphStyle(name="Bulletx", parent=s["Bodyx"], leftIndent=16, firstLineIndent=-8,
                         bulletIndent=4, spaceAfter=5))
    s.add(ParagraphStyle(name="Captionx", parent=s["Bodyx"], fontName="Times-Italic",
                         fontSize=9, leading=12, alignment=TA_CENTER, textColor=GREY))
    s.add(ParagraphStyle(name="Codex", parent=s["Code"], fontName="Courier", fontSize=7.7,
                         leading=11, leftIndent=8, rightIndent=8, borderColor=colors.HexColor("#B9C8D2"),
                         borderWidth=.5, borderPadding=8, backColor=colors.HexColor("#F5F7F8"), spaceAfter=8))
    s.add(ParagraphStyle(name="Centerx", parent=s["Bodyx"], alignment=TA_CENTER))
    return s


def table(data, widths=None, header=True):
    cell_style = ParagraphStyle("TableCell", fontName="Times-Roman", fontSize=8.2,
                                leading=10.2, textColor=GREY)
    head_style = ParagraphStyle("TableHead", parent=cell_style, fontName="Times-Bold",
                                textColor=colors.white)
    wrapped = []
    for row_index, row in enumerate(data):
        wrapped.append([
            Paragraph(str(value).replace("\n", "<br/>"), head_style if header and row_index == 0 else cell_style)
            if isinstance(value, str) else value
            for value in row
        ])
    t = Table(wrapped, colWidths=widths, repeatRows=1 if header else 0, hAlign="LEFT")
    commands = [
        ("FONT", (0, 0), (-1, -1), "Times-Roman", 9),
        ("TEXTCOLOR", (0, 0), (-1, -1), GREY),
        ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
        ("LEFTPADDING", (0, 0), (-1, -1), 7), ("RIGHTPADDING", (0, 0), (-1, -1), 7),
        ("TOPPADDING", (0, 0), (-1, -1), 6), ("BOTTOMPADDING", (0, 0), (-1, -1), 6),
        ("GRID", (0, 0), (-1, -1), .35, colors.HexColor("#C6D1D7")),
        ("ROWBACKGROUNDS", (0, 1), (-1, -1), [colors.white, colors.HexColor("#F6F8F9")]),
    ]
    if header:
        commands += [("BACKGROUND", (0, 0), (-1, 0), NAVY),
                     ("TEXTCOLOR", (0, 0), (-1, 0), colors.white),
                     ("FONT", (0, 0), (-1, 0), "Times-Bold", 9)]
    t.setStyle(TableStyle(commands))
    return t


def p(text, st): return Paragraph(text, st)
def bullet(text, st): return Paragraph(text, st, bulletText="-")


def build():
    figures = make_figures()
    S = styles()
    OUT.mkdir(parents=True, exist_ok=True)
    story = []

    # Cover
    story += [Spacer(1, 1.0*cm), p("NATIONAL INSTITUTE OF BUSINESS MANAGEMENT", S["CoverSmall"]),
              p("School of Computing and Engineering", S["CoverSmall"]), Spacer(1, .8*cm),
              p("Higher National Diploma in Software Engineering", S["CoverSmall"]),
              p("HNDSE 25.1 P - Kandy", S["CoverSmall"]), p("Machine Learning", S["CoverSmall"]),
              p("FINAL REPORT", S["CoverSmall"]), Spacer(1, 1.0*cm),
              p("ALFA COMMUNITY", S["CoverTitle"]),
              p("A Location-Aware Mobile Safety Platform with Flood, Landslide, Garbage and Elephant Machine Learning", S["CoverSmall"]),
              Spacer(1, 1.0*cm), p("Submitted by", S["CoverSmall"]),
              table([["Student name(s)", "Student ID(s)"], ["____________________________", "____________________________"],
                     ["____________________________", "____________________________"], ["____________________________", "____________________________"]],
                    [8*cm, 8*cm]), Spacer(1, 1.2*cm),
              p("Submitted date: 07 July 2026", S["Centerx"]), PageBreak()]

    story += [p("Declaration", S["H1x"]), p("We declare that the project <b>Alfa Community</b> is original work prepared for the Machine Learning module. All external datasets, libraries and ideas must be acknowledged in the submitted version. AI-assisted code and writing were used as support tools; the submitting students remain responsible for understanding, verifying and presenting every component of the work.", S["Bodyx"]),
              Spacer(1, 1.5*cm), p("Signatures", S["H2x"]),
              table([["Name", "Signature", "Date"], ["", "", ""], ["", "", ""], ["", "", ""]], [6*cm, 5*cm, 4.5*cm]), PageBreak(),
              p("Acknowledgement", S["H1x"]), p("We express our sincere gratitude to our module lecturer for guidance throughout the proposal, exploratory analysis, modelling and mobile deployment phases. We also acknowledge the maintainers of the Kaggle datasets, TensorFlow, scikit-learn, Ultralytics YOLO and Flutter ecosystems that made this applied project possible.", S["Bodyx"]),
              p("The project provided practical experience in data quality assessment, reusable preprocessing, model evaluation, on-device inference and responsible communication of safety-related predictions.", S["Bodyx"]), PageBreak()]

    story += [p("Contents", S["H1x"])]
    contents = ["1. Introduction", "2. System Architecture and Environment", "3. Dataset Collection and Exploratory Data Analysis",
                "4. Data Preprocessing Pipeline", "5. Machine Learning Model Development", "6. Hyperparameter Tuning and Evaluation",
                "7. On-Device Model Integration", "8. Mobile Application and Data Persistence", "9. Testing and Reproducibility",
                "10. Conclusion and Reflection", "References", "Appendix A: Reproduction Commands"]
    story += [p(item, S["Bodyx"]) for item in contents] + [Spacer(1, .4*cm), p("List of Figures", S["H2x"])]
    for item in ["Figure 1: Alfa Community system architecture", "Figure 2: Flood and landslide target distributions",
                 "Figure 3: Landslide correlation matrix", "Figure 4: Garbage class distribution",
                 "Figure 5: Elephant detector validation metrics", "Figure 6: Reusable training and deployment pipeline"]:
        story.append(p(item, S["Bodyx"]))
    story.append(PageBreak())

    story += [p("1. Introduction", S["H1x"]), p("1.1 Problem Statement and Objectives", S["H2x"]),
              p("Rural and semi-urban communities face several recurring safety problems: local flooding, slope instability, unmanaged waste and human-elephant conflict. Information is often fragmented across residents, field officers and authorities, while internet connectivity may be unreliable. Alfa Community addresses this gap through a Flutter mobile application that combines local sensing inputs, image-based prediction, on-device ML inference, GPS context and an auditable community-report workflow.", S["Bodyx"]),
              p("The project objective is to design, train and integrate independent models for four safety modules while keeping the user experience coherent. Flood and landslide modules perform three-class risk prediction; garbage uses ten-class image classification; and elephant monitoring uses single-class object detection.", S["Bodyx"]),
              p("1.2 Project Scope", S["H2x"])]
    for x in ["Provide input screens with clear loading, validation and error states.", "Run trained TensorFlow Lite models on the mobile device where feasible.", "Store recent predictions for historical comparison.", "Evaluate each ML task with metrics appropriate to its output type.", "Present uncertainty and safety limitations instead of treating predictions as official alerts."]:
        story.append(bullet(x, S["Bulletx"]))
    story += [p("1.3 Research Questions", S["H2x"]), p("The work investigates whether compact mobile-ready models can provide useful first-pass community safety signals, which predictors contribute most to risk classification, how class imbalance affects evaluation, and what limitations must be addressed before real-world operational use.", S["Bodyx"]), PageBreak()]

    story += [p("2. System Architecture and Environment Setup", S["H1x"]), p("2.1 Technology Stack", S["H2x"]),
              table([["Layer", "Technology", "Purpose"], ["Mobile client", "Flutter / Dart", "Cross-platform UI and local model inference"],
                     ["ML training", "Python, pandas, scikit-learn, TensorFlow", "EDA, preprocessing, training and evaluation"],
                     ["Vision", "Ultralytics YOLO11, MobileNetV2", "Elephant detection and waste classification"],
                     ["Persistence", "SQLite, SharedPreferences, Firebase-ready stores", "Users, reports and prediction history"],
                     ["Deployment", "TensorFlow Lite", "Offline inference on Android/iOS"]], [3.1*cm, 5.2*cm, 7.5*cm]),
              Spacer(1, .5*cm), p("2.2 High-Level Architecture", S["H2x"]),
              table([["Flutter Inputs", "Model Services", "Outputs"], ["Camera / Gallery\nRisk sliders\nGPS profile", "YOLO detector\nMobileNet classifier\nTabular TFLite models", "Prediction + confidence\nSafety guidance\nLocal history"]], [5.1*cm, 5.4*cm, 5.3*cm]),
              p("Figure 1: Alfa Community system architecture.", S["Captionx"]),
              p("Each model is isolated behind a Dart service. This modular design allows one model to be updated without retraining or redeploying every other module. The risk screens attempt TFLite inference first and visibly identify development fallback results when an asset cannot be loaded.", S["Bodyx"]),
              p("2.3 Project Structure", S["H2x"]), p("lib/src/plugins/       module screens<br/>lib/src/services/      inference, persistence and location<br/>ml/                    preparation, training and evaluation<br/>datasets/              raw and processed datasets<br/>assets/models/          exported TFLite assets<br/>test/                   Flutter automated tests", S["Codex"]), PageBreak()]

    story += [p("3. Dataset Collection and Exploratory Data Analysis", S["H1x"]), p("3.1 Data Sources", S["H2x"]),
              p("The flood dataset was prepared from the Kaggle India Flood Risk dataset. The landslide dataset was prepared from a wireless-sensor-network landslide dataset. Garbage images use the Kaggle Garbage Classification V2 collection. Elephant images use a YOLO-formatted elephant dataset containing train, validation and test splits. Exact Kaggle URLs and licence terms must be inserted into the final submitted reference list from the download pages used by the team.", S["Bodyx"]),
              table([["Module", "Records / images", "Target", "Input features"], ["Flood", "10,000", "Low / medium / high", "24h rainfall, water level, drainage"],
                     ["Landslide", "9,864", "Low / medium / high", "72h rainfall, slope, soil moisture"],
                     ["Garbage", "12,259", "10 material classes", "224 x 224 RGB image"],
                     ["Elephant", "25,217 images", "Elephant bounding boxes", "YOLO images and labels"]], [3*cm, 3.3*cm, 4.2*cm, 5.3*cm]),
              p("3.2 Missing Values and Data Quality", S["H2x"]),
              p("Flood and landslide processed tables contain no missing values. Median imputation remains part of the reusable preprocessing pipeline to safely handle future incomplete records. Image datasets require additional checks for corrupt files, incorrect annotations, duplicates, near-duplicate video frames and background leakage.", S["Bodyx"]), PageBreak(),
              p("3.3 Flood and Landslide EDA", S["H2x"]), Image(str(figures["risk_classes"]), width=15.8*cm, height=7.55*cm),
              p("Figure 2: Flood and landslide target distributions.", S["Captionx"]),
              table([["Dataset", "Low", "Medium", "High", "Missing"], ["Flood", "1,209 (12.09%)", "3,734 (37.34%)", "5,057 (50.57%)", "0"],
                     ["Landslide", "2,381 (24.14%)", "2,524 (25.59%)", "4,959 (50.27%)", "0"]], [3.2*cm, 3.4*cm, 3.6*cm, 3.6*cm, 2*cm]),
              p("Both targets are imbalanced toward high risk. Flood correlations with the target are weak: rainfall 0.093, water level 0.080 and drainage -0.006. In contrast, landslide slope has a strong 0.811 correlation with risk, while rainfall and moisture show weaker correlations of 0.152 and 0.159.", S["Bodyx"]),
              Image(str(figures["landslide_corr"]), width=12.2*cm, height=9.4*cm), p("Figure 3: Landslide correlation matrix.", S["Captionx"]), PageBreak(),
              p("3.4 Garbage Image EDA", S["H2x"]), Image(str(figures["garbage"]), width=15.8*cm, height=7.7*cm),
              p("Figure 4: Garbage dataset class distribution.", S["Captionx"]),
              p("The garbage dataset contains 10,426 training and 1,833 validation images. Clothes is the largest class (1,892 images; 15.43%), while trash is the smallest (453 images; 3.70%). The largest class is over four times the smallest, so macro-F1 and per-class recall are necessary alongside accuracy. A separate held-out test set should be created before final assessment.", S["Bodyx"]),
              p("3.5 Elephant Detection EDA", S["H2x"]),
              table([["Split", "Images", "Label files", "Share"], ["Training", "20,173", "20,173", "80.00%"],
                     ["Validation", "2,521", "2,521", "10.00%"], ["Testing", "2,523", "2,523", "10.00%"]], [4*cm]*4),
              p("The single-class YOLO dataset has a strong 80/10/10 split and a matching label file for every discovered image. Before operational use, the team should quantify empty labels, bounding-box sizes, difficult night scenes, occlusion, and duplicate frames across splits.", S["Bodyx"]),
              p("3.6 EDA Implications", S["H2x"])]
    for x in ["Use stratified splits for tabular and image classification.", "Optimise macro-F1 where minority-class performance matters.", "Treat slope dominance in landslide prediction as a possible label-design warning.", "Add authority-validated labels and broader features before safety deployment.", "Do not describe these datasets as time-series forecasting because they contain no timestamp field."]:
        story.append(bullet(x, S["Bulletx"]))
    story.append(PageBreak())

    story += [p("4. Data Preprocessing Pipeline", S["H1x"]), p("4.1 Reusable Tabular Pipeline", S["H2x"]),
              p("Flood evaluation uses a scikit-learn Pipeline with numeric coercion, median imputation and standardisation. The fixed random seed is 42. Data is divided into training, validation and held-out test partitions using stratification to preserve class proportions and avoid evaluating on training records.", S["Bodyx"]),
              p("numeric = Pipeline([<br/>&nbsp;&nbsp;('imputer', SimpleImputer(strategy='median')),<br/>&nbsp;&nbsp;('scale', StandardScaler())<br/>])<br/>pipeline = Pipeline([('preprocess', transformer), ('model', classifier)])", S["Codex"]),
              p("4.2 Risk Feature Engineering", S["H2x"]),
              p("Flood features are rainfall over 24 hours, river or drain water level, and drainage effectiveness. Landslide features are rainfall over 72 hours, terrain slope and soil moisture. The current risk targets were derived during dataset preparation. This enables demonstration but is a limitation because derived labels can encode threshold assumptions rather than independent observed outcomes.", S["Bodyx"]),
              p("4.3 Image Preprocessing and Augmentation", S["H2x"]),
              p("Garbage images are resized to 224 x 224 pixels and passed through MobileNetV2 preprocessing, which scales values to the range expected by the pretrained backbone. Elephant training uses 320-pixel inputs in the completed CPU experiment, with translation, scale, horizontal flip, HSV and mosaic augmentations configured by YOLO.", S["Bodyx"]),
              p("4.4 Leakage Controls", S["H2x"])]
    for x in ["Fit imputers and scalers only on training data through the pipeline.", "Keep the test set untouched until final evaluation.", "Detect duplicate images before splitting image datasets.", "Group related video frames or locations so similar scenes cannot enter different splits."]:
        story.append(bullet(x, S["Bulletx"]))
    story += [table([["Raw data", "Validation", "Preprocessing", "Split", "Training", "TFLite export"], ["CSV / images", "Schema / labels", "Scale / resize", "Train-val-test", "Compare + tune", "Mobile asset"]], [2.65*cm]*6),
              p("Figure 6: Reusable training and deployment pipeline.", S["Captionx"]), PageBreak()]

    story += [p("5. Machine Learning Model Development", S["H1x"]), p("5.1 Flood Baseline Models", S["H2x"]),
              p("Logistic Regression was selected as an interpretable linear baseline. Random Forest was selected to capture nonlinear interactions without requiring feature scaling assumptions. On validation data, Logistic Regression reached 50.15% accuracy and 0.2953 macro-F1; Random Forest reached 45.65% accuracy and 0.3940 macro-F1. The latter is better balanced across classes despite lower overall accuracy.", S["Bodyx"]),
              table([["Model", "Validation accuracy", "Validation macro-F1"], ["Logistic Regression", "0.5015", "0.2953"], ["Random Forest", "0.4565", "0.3940"]], [6*cm, 5*cm, 5*cm]),
              p("5.2 Landslide Risk Model", S["H2x"]),
              p("The mobile landslide model is a compact neural network with normalisation, dense ReLU layers, dropout and a three-neuron softmax output. It is exported to TensorFlow Lite. A full independent test report should be retained during the final retraining run; the current repository does not preserve those metrics, so this report does not invent them.", S["Bodyx"]),
              p("5.3 Garbage Classification Model", S["H2x"]),
              p("Transfer learning uses MobileNetV2 with ImageNet weights as a frozen feature extractor, followed by global average pooling, dropout and a ten-class softmax layer. The architecture is suitable for mobile deployment because it offers a strong speed-size trade-off. The exported model is approximately 2.54 MB.", S["Bodyx"]),
              p("5.4 Elephant Object Detector", S["H2x"]),
              p("YOLO11n was chosen for single-stage elephant detection. It predicts bounding boxes and confidence in one pass, which is appropriate for responsive camera inference. The completed experiment used five CPU epochs, batch size four and 320-pixel input images.", S["Bodyx"]), PageBreak(),
              p("5.5 Elephant Training Results", S["H2x"]), Image(str(figures["elephant_metrics"]), width=15.8*cm, height=7.55*cm),
              p("Figure 5: Elephant detector validation metrics.", S["Captionx"]),
              table([["Metric", "Epoch 1", "Epoch 5"], ["Precision", "0.8331", "0.9216"], ["Recall", "0.7640", "0.8623"],
                     ["mAP@0.50", "0.8464", "0.9367"], ["mAP@0.50:0.95", "0.5125", "0.6669"]], [6*cm, 5*cm, 5*cm]),
              p("All four validation measures improved over the five epochs. The final mAP@0.50 of 0.9367 is promising; however, this short experiment is not enough to establish field reliability. Evaluation should be repeated on the untouched test split and on local day/night camera footage.", S["Bodyx"]),
              Image(str(ROOT / "runs/detect/runs/elephant/alfa_elephant_cpu_5e/confusion_matrix.png"), width=9.2*cm, height=7.0*cm),
              p("Elephant detector confusion matrix generated by Ultralytics.", S["Captionx"]), PageBreak()]

    story += [p("6. Hyperparameter Tuning and Performance Evaluation", S["H1x"]),
              p("6.1 Tuning Strategy", S["H2x"]), p("The flood Random Forest was tuned with RandomizedSearchCV using five-fold stratified cross-validation and macro-F1 scoring. The search covered 100-500 trees, maximum depth values of 8-24 or unrestricted depth, minimum split sizes of 2-10 and optional balanced class weights.", S["Bodyx"]),
              p("Best parameters: 300 estimators, maximum depth 24, minimum samples split 10, and balanced class weights.", S["Bodyx"]),
              p("6.2 Held-Out Test Comparison", S["H2x"]),
              table([["Model", "Accuracy", "Macro-F1"], ["Baseline Random Forest", "0.4645", "0.3871"], ["Tuned Random Forest", "0.4190", "0.4098"]], [7*cm, 4.5*cm, 4.5*cm]),
              p("Tuning improved macro-F1 from 0.3871 to 0.4098 but reduced accuracy from 0.4645 to 0.4190. This trade-off indicates that balanced class weights improved minority-class attention while reducing majority-class correctness. The tuned model achieved class recalls of 0.61 for low, 0.49 for medium and 0.32 for high risk.", S["Bodyx"]),
              Image(str(ROOT / "ml/artifacts/flood/confusion_matrix.png"), width=10.8*cm, height=8.15*cm),
              p("Flood tuned-model confusion matrix on 2,000 held-out records.", S["Captionx"]),
              KeepTogether([p("6.3 Interpretation", S["H2x"]),
              p("The flood result is not production quality. The weak correlations and overlap between medium and high risk show that three mobile inputs do not contain enough information to reproduce the derived labels. The correct next step is feature and label improvement, not repeated tuning against an information-poor representation.", S["Bodyx"])]), PageBreak()]

    story += [p("7. On-Device Model Integration", S["H1x"]), p("7.1 TensorFlow Lite Deployment", S["H2x"]),
              p("Flood, landslide and garbage models are stored under assets/models and loaded through tflite_flutter. Model input and output tensor shapes are validated before inference. The tabular contract requires three finite numeric inputs and three output probabilities corresponding to low, medium and high risk.", S["Bodyx"]),
              p("final inputShape = interpreter.getInputTensor(0).shape;<br/>if (inputShape.last != features.length) {<br/>&nbsp;&nbsp;throw StateError('Unexpected feature count');<br/>}<br/>interpreter.run([features], output);", S["Codex"]),
              p("7.2 Confidence and Guidance", S["H2x"]), p("The highest softmax probability is displayed as confidence and mapped to module-specific guidance. The interface identifies whether a result came from the trained model or a development rule. This separation prevents a fallback heuristic from being misrepresented as ML output.", S["Bodyx"]),
              p("7.3 Elephant Decoder Boundary", S["H2x"]), p("The elephant TFLite asset is included, but safe bounding-box decoding must match the exact YOLO export tensor contract. The application should not claim operational detection until post-processing, non-maximum suppression, coordinate conversion and device-level tests have been verified against the exported model version.", S["Bodyx"]),
              p("7.4 Model Governance", S["H2x"])]
    for x in ["Version model assets and label maps together.", "Record dataset source, preprocessing parameters and evaluation metrics.", "Reject invalid tensor contracts rather than silently producing outputs.", "Use official alerts and field officers for emergency decisions."]:
        story.append(bullet(x, S["Bulletx"]))
    story.append(PageBreak())

    story += [p("8. Mobile Application and Data Persistence", S["H1x"]), p("8.1 Core User Journey", S["H2x"]),
              p("Users authenticate as citizens, officers or administrators. The home dashboard selects relevant safety modules using GPS context. Flood and landslide screens allow users to adjust environmental inputs and run predictions. Garbage and elephant screens accept camera or gallery images. Results are presented with confidence, contextual guidance and visible loading or error states.", S["Bodyx"]),
              p("8.2 Prediction History", S["H2x"]), p("Recent flood and landslide assessments are persisted locally with timestamp, module, inputs, predicted level, confidence and inference source. The five latest results are displayed for comparison, satisfying the requirement for a historical view without depending on internet access.", S["Bodyx"]),
              p("8.3 Community Workflow", S["H2x"]), p("Citizens can submit community reports. Officers can receive assignments and update operational status, while administrators resolve completed reports. SQLite provides offline-first persistence and Firebase-ready services support future cloud synchronisation.", S["Bodyx"]),
              p("8.4 UI/UX and Accessibility", S["H2x"])]
    for x in ["Responsive list layouts and large touch targets support mobile use.", "Risk states use text labels in addition to colour.", "Progress indicators prevent repeated requests during inference.", "Errors are shown near the prediction action and can be retried.", "Safety wording states uncertainty and directs emergencies to authorities."]:
        story.append(bullet(x, S["Bulletx"]))
    story += [p("8.5 Security and Privacy", S["H2x"]), p("Provider API keys are kept outside Flutter source because secrets embedded in a mobile binary can be extracted. Location and image data should be collected only with consent, stored for the minimum necessary period, and protected with access control. Production deployment also requires authentication, rate limiting and moderation on hosted assistant endpoints.", S["Bodyx"]), PageBreak()]

    story += [p("9. Testing and Reproducibility", S["H1x"]), p("9.1 Automated Tests", S["H2x"]),
              p("The Flutter test suite covers authentication, unique user identifiers, role-specific dashboard access, GPS-based module selection, community report transitions, offline assistant behaviour, risk fallback scoring and prediction-history persistence. At the latest verification pass, all 11 tests passed and Flutter static analysis reported no issues.", S["Bodyx"]),
              p("9.2 Reproducible ML Workflow", S["H2x"]),
              p("The coursework flood pipeline writes an EDA summary, distribution chart, baseline comparison, tuned parameters, classification report and confusion matrix to ml/artifacts/flood. Random seeds and preprocessing are defined in source code. Training dependencies are pinned by compatible version ranges in ml/requirements-coursework.txt.", S["Bodyx"]),
              p("9.3 Acceptance Criteria", S["H2x"]),
              table([["Area", "Acceptance check", "Status"], ["Data", "Schema and missing-value audit", "Completed"], ["Model", "Held-out flood evaluation", "Completed"],
                     ["Vision", "Elephant validation metrics", "Completed (5-epoch experiment)"], ["Mobile", "TFLite loading and history", "Completed"],
                     ["Quality", "Flutter analyze and automated tests", "Passed"], ["Field safety", "Authority validation and local pilot", "Not yet completed"]], [3.3*cm, 9.5*cm, 3.2*cm]),
              p("9.4 Demonstration Plan", S["H2x"])]
    for x in ["Open the dashboard and explain GPS-based module selection.", "Run flood and landslide predictions with low and high input scenarios.", "Show confidence, model-source label and stored history.", "Classify a garbage photograph.", "Present elephant training plots and explain the remaining decoder validation.", "Close with limitations and the plan for authority-validated data."]:
        story.append(bullet(x, S["Bulletx"]))
    story.append(PageBreak())

    story += [p("10. Conclusion and Reflection", S["H1x"]), p("10.1 Conclusion", S["H2x"]),
              p("Alfa Community demonstrates an end-to-end applied ML system spanning dataset preparation, EDA, reusable preprocessing, baseline comparison, tuning, TFLite deployment and a working Flutter experience. The strongest experimental result is the YOLO elephant detector, which reached 0.9367 mAP@0.50 after five CPU epochs. The flood experiment is equally valuable academically because it exposes a genuine feature and label limitation rather than hiding weak performance.", S["Bodyx"]),
              p("10.2 Challenges and Limitations", S["H2x"])]
    for x in ["Flood labels cannot be predicted reliably from only three selected features.", "Risk labels are derived and require expert validation.", "The garbage training run needs a preserved independent test report.", "The elephant TFLite decoder must be verified against the exact export contract.", "Image and hazard models may not generalise to Sri Lankan field conditions without local data.", "Predictions are decision-support signals, not official emergency warnings."]:
        story.append(bullet(x, S["Bulletx"]))
    story += [p("10.3 Key Technical Learnings", S["H2x"]), p("The project reinforced that dataset design and label validity matter more than algorithm complexity; macro metrics reveal failures hidden by accuracy; model export is only one part of deployment; and a useful ML system also requires validation, persistence, error handling, privacy controls and transparent communication of uncertainty.", S["Bodyx"]),
              p("10.4 Future Work", S["H2x"])]
    for x in ["Collect local, timestamped sensor and incident data for true forecasting.", "Add terrain, river capacity, soil type, land use and historical event features.", "Create a held-out garbage test set and investigate class-balanced fine-tuning.", "Train the elephant detector longer on GPU and test day/night edge cases.", "Complete YOLO TFLite post-processing and benchmark latency on target devices.", "Conduct a supervised field pilot with disaster, wildlife and municipal officers."]:
        story.append(bullet(x, S["Bulletx"]))
    story.append(PageBreak())

    story += [p("References", S["H1x"]),
              p("1. Breiman, L. (2001). Random Forests. <i>Machine Learning</i>, 45, 5-32.", S["Bodyx"]),
              p("2. Howard, A. et al. (2017). MobileNets: Efficient Convolutional Neural Networks for Mobile Vision Applications.", S["Bodyx"]),
              p("3. Ultralytics. YOLO documentation and model training framework. https://docs.ultralytics.com/", S["Bodyx"]),
              p("4. TensorFlow. TensorFlow Lite documentation. https://www.tensorflow.org/lite", S["Bodyx"]),
              p("5. scikit-learn developers. Pipeline, RandomForestClassifier and RandomizedSearchCV documentation. https://scikit-learn.org/", S["Bodyx"]),
              p("6. Kaggle dataset pages used for flood risk, garbage classification and elephant detection. <b>Insert exact dataset URLs and access dates before submission.</b>", S["Bodyx"]),
              p("7. Wireless sensor network landslide dataset source. <b>Insert exact repository or Kaggle URL and licence before submission.</b>", S["Bodyx"]), PageBreak(),
              p("Appendix A: Reproduction Commands", S["H1x"]),
              p("python -m pip install -r ml/requirements-coursework.txt<br/>python ml/prepare_risk_csvs.py<br/>python ml/coursework_flood_pipeline.py<br/>python ml/flood/train.py --csv datasets/flood/flood.csv --output assets/models/flood_model.tflite<br/>python ml/landslide/train.py --csv datasets/landslide/landslide.csv --output assets/models/landslide_model.tflite<br/>python ml/garbage/train.py --dataset datasets/garbage --output assets/models/garbage_model.tflite<br/>python ml/train_elephant_detector.py --data datasets/elephant/data.yaml --epochs 50<br/>flutter test<br/>flutter analyze", S["Codex"]),
              p("Submission checklist", S["H2x"])]
    for x in ["Replace cover-page name and ID lines.", "Insert exact Kaggle URLs, licences and access dates.", "Add contribution percentages for every group member.", "Attach the executed notebook and generated charts.", "Build and test the APK on a physical Android device.", "Ensure every group member can explain the code, metrics and limitations."]:
        story.append(bullet(x, S["Bulletx"]))

    ReportDoc(str(PDF)).build(story)
    print(PDF)


if __name__ == "__main__":
    build()
