#!/usr/bin/env python3
from fpdf import FPDF

ICON = "../ShiftBlast/Assets.xcassets/AppIcon.appiconset/block-blast-icon-1024.png"
NAVY = (11, 31, 58)
HEAD = (22, 52, 95)
BLUE = (43, 95, 209)
GREY = (90, 90, 90)
DARK = (26, 26, 26)

class PDF(FPDF):
    def footer(self):
        self.set_y(-15)
        self.set_font("Helvetica", "", 8)
        self.set_text_color(*GREY)
        self.cell(0, 10, f"ShiftBlast - Capolavoro dello studente   |   pag. {self.page_no()}",
                  align="C")

pdf = PDF(format="A4")
pdf.set_auto_page_break(True, margin=20)
pdf.set_margins(22, 20, 22)
pdf.add_page()

def h2(txt):
    pdf.ln(4)
    pdf.set_font("Helvetica", "B", 15)
    pdf.set_text_color(*NAVY)
    pdf.cell(0, 9, txt, new_x="LMARGIN", new_y="NEXT")
    y = pdf.get_y()
    pdf.set_draw_color(*BLUE)
    pdf.set_line_width(0.6)
    pdf.line(22, y, 188, y)
    pdf.ln(3)

def h3(txt):
    pdf.ln(1)
    pdf.set_font("Helvetica", "B", 11)
    pdf.set_text_color(*HEAD)
    pdf.multi_cell(0, 6, txt, new_x="LMARGIN", new_y="NEXT")

def body(txt):
    pdf.set_font("Helvetica", "", 10.5)
    pdf.set_text_color(*DARK)
    pdf.multi_cell(0, 5.6, txt, new_x="LMARGIN", new_y="NEXT")
    pdf.ln(1.5)

def bullet(label, txt):
    pdf.set_x(26)
    pdf.set_font("Helvetica", "", 10.5)
    pdf.set_text_color(*DARK)
    pdf.multi_cell(162, 5.6, f"**- {label}** {txt}", markdown=True,
                   align="L", new_x="LMARGIN", new_y="NEXT")
    pdf.ln(0.8)

def step(num, label, txt):
    pdf.set_x(22)
    pdf.set_font("Helvetica", "", 10.5)
    pdf.set_text_color(*DARK)
    pdf.multi_cell(166, 5.6, f"**{num}. {label}** {txt}", markdown=True,
                   align="L", new_x="LMARGIN", new_y="NEXT")
    pdf.ln(1.5)

# ---------- COVER ----------
pdf.ln(28)
pdf.image(ICON, x=(210-42)/2, y=None, w=42)
pdf.ln(6)
pdf.set_font("Helvetica", "B", 30)
pdf.set_text_color(*NAVY)
pdf.cell(0, 14, "ShiftBlast", align="C", new_x="LMARGIN", new_y="NEXT")
pdf.set_font("Helvetica", "", 13)
pdf.set_text_color(*GREY)
pdf.cell(0, 8, "Un gioco puzzle per iPhone e Mac, dall'idea alla pubblicazione",
         align="C", new_x="LMARGIN", new_y="NEXT")
pdf.ln(10)
pdf.set_font("Helvetica", "", 11)
pdf.set_text_color(*DARK)
pdf.cell(0, 7, "Capolavoro dello studente - Progetto individuale", align="C",
         new_x="LMARGIN", new_y="NEXT")
pdf.cell(0, 7, "Progettazione, programmazione e pubblicazione: Davide Capurro",
         align="C", new_x="LMARGIN", new_y="NEXT")
pdf.ln(14)

# ---------- COS'E' ----------
h2("Cos'e' ShiftBlast")
body("ShiftBlast e' un gioco puzzle che ho ideato e scritto da zero per iPhone e Mac. "
     "Si gioca su una griglia: con uno swipe si fanno scorrere tutti i blocchi nella stessa "
     "direzione, e quando una riga o una colonna si riempie viene eliminata. L'obiettivo e' "
     "tenere la griglia libera il piu' a lungo possibile e fare punteggio.")
body("Le meccaniche che ho costruito vanno oltre il semplice \"riempi la linea\":")
bullet("Chain:", "eliminare piu' linee di fila aumenta il moltiplicatore, quindi incatenare "
       "le mosse vale molto piu' che eliminarle una alla volta.")
bullet("Overdrive:", "riempiendo una barra di carica (soglia a 90) si attiva una pulizia "
       "speciale del tabellone, con la sua animazione dedicata.")
bullet("Spawn riproducibili:", "la generazione dei blocchi parte da un seed, cosi' una "
       "partita puo' essere rigiocata identica. Mi e' servito soprattutto per testare i bug.")
pdf.ln(1)
body("Il punteggio base e' di 400 punti a linea, a cui si sommano i bonus di chain e overdrive. "
     "La difficolta' sale con il punteggio e con il numero di mosse, in livelli che ho tarato a mano.")

# ---------- COM'E' FATTO ----------
h2("Com'e' fatto")
body("L'ho scritto in Swift con SwiftUI. La scelta tecnica di cui sono piu' contento e' aver "
     "separato nettamente la logica di gioco dall'interfaccia: tutte le regole stanno in un motore "
     "(GameEngine) fatto di funzioni pure su uno stato Codable, mentre le viste si limitano a "
     "disegnare quello stato. Cosi' ho potuto cambiare animazioni e grafica senza toccare le regole, "
     "e ho ritrovato i bug piu' facilmente.")

tech = [
    ("Linguaggio e UI", "Swift, SwiftUI - circa 6.000 righe di codice in tutto il progetto"),
    ("Classifiche", "Game Center con classifica personale e globale, piu' una schermata a tutto schermo"),
    ("Social", "Classifiche tra amici e notifiche quando un amico ti supera"),
    ("Monetizzazione", "Abbonamento con StoreKit e schermata paywall; banner AdMob con richiesta di consenso"),
    ("Pubblicazione", "Pubblicato sull'App Store; pagine Privacy e Termini ospitate su GitHub Pages"),
    ("Extra", "App companion per Mac (\"Relay\") e una piccola landing page del gioco"),
]
pdf.ln(1)
for k, v in tech:
    x0 = pdf.get_x()
    y0 = pdf.get_y()
    pdf.set_font("Helvetica", "B", 10)
    pdf.set_text_color(*HEAD)
    pdf.multi_cell(46, 5.4, k, border=0)
    y1 = pdf.get_y()
    pdf.set_xy(x0 + 46, y0)
    pdf.set_font("Helvetica", "", 10)
    pdf.set_text_color(*DARK)
    pdf.multi_cell(166 - 46, 5.4, v, border=0)
    y2 = pdf.get_y()
    yb = max(y1, y2)
    pdf.set_draw_color(225, 225, 225)
    pdf.set_line_width(0.2)
    pdf.line(22, yb + 0.5, 188, yb + 0.5)
    pdf.set_xy(x0, yb + 1.2)

# ---------- PERCORSO ----------
h2("Il percorso che ho seguito")
body("Non e' nato gia' finito. L'ho costruito a tappe, e ogni tappa e' rimasta registrata "
     "nella cronologia del progetto su Git:")
step(1, "Prima versione giocabile.", "Ho messo in piedi la griglia, lo scorrimento con swipe e "
     "l'eliminazione delle linee. Qui ho deciso la struttura del motore separato dalla UI, che poi "
     "ha pagato per tutto il resto.")
step(2, "Preparazione all'App Store.", "Per pubblicare ho dovuto sistemare i blocchi segnalati dalla "
     "review di Apple, scrivere e mettere online le pagine di Privacy e Termini, e collegarle dalle "
     "impostazioni dell'app.")
step(3, "Classifiche Game Center.", "Ho integrato l'accesso a Game Center con messaggi di login piu' "
     "chiari, e ho aggiunto la classifica con scheda personale e globale.")
step(4, "Pubblicita' con consenso.", "Ho inizializzato AdMob usando annunci di test in TestFlight e "
     "quelli reali in produzione, gestendo la richiesta di consenso prima di mostrarli.")
step(5, "Parte social.", "Ho aggiunto le classifiche tra amici, le notifiche e un interruttore per "
     "attivarle o disattivarle.")

# ---------- PROBLEMI ----------
h2("Problemi veri che ho dovuto risolvere")
h3("I blocchi sparivano senza animazione")
body("Quando l'Overdrive ripuliva il tabellone, i blocchi venivano rimossi di colpo: sparivano e "
     "basta, senza l'animazione di eliminazione. Ho capito che il problema era il punto in cui li "
     "toglievo dallo stato. Ho fatto passare la rimozione attraverso lo stesso insieme di blocchi "
     "\"in eliminazione\" (clearingBlockIDs) usato dalle linee normali, cosi' l'animazione parte "
     "anche per l'Overdrive.")
h3("La difficolta' saliva troppo in fretta")
body("Le prime partite diventavano ingiocabili dopo poco e si somigliavano tutte. Ho ammorbidito la "
     "curva di difficolta' e reso piu' vari gli spawn, cosi' le partite durano di piu' e ognuna e' "
     "diversa dalla precedente.")
h3("Contrasto e leggibilita' della griglia")
body("Sui blocchi al neon non si distingueva bene quale fosse appena comparso. Ho alzato il "
     "contrasto dei blocchi e abbassato il bagliore di quelli fermi, in modo che la comparsa di un "
     "nuovo blocco si notasse.")

# ---------- COMPETENZE ----------
h2("Competenze che ho sviluppato")
bullet("Programmazione:", "Swift e SwiftUI, separazione tra logica e interfaccia, gestione dello "
       "stato e delle animazioni.")
bullet("Risoluzione di problemi:", "riprodurre un bug grazie al seed, capirne la causa reale e "
       "correggerlo invece di mascherarlo.")
bullet("Pubblicazione di un prodotto:", "requisiti dell'App Store, privacy e termini, abbonamenti, "
       "pubblicita' e consenso.")
bullet("Autonomia e costanza:", "ho portato avanti il progetto da solo, a tappe, fino a farlo "
       "arrivare nelle mani di altre persone.")
pdf.ln(4)
pdf.set_font("Helvetica", "I", 10.5)
pdf.set_text_color(*GREY)
pdf.multi_cell(0, 5.6, "ShiftBlast e' il progetto in cui ho imparato di piu', perche' mi ha "
               "costretto a occuparmi di tutto: l'idea, il codice, i bug, la pubblicazione e le "
               "persone che poi ci giocano davvero.")

pdf.output("ShiftBlast-Capolavoro.pdf")
print("OK")
