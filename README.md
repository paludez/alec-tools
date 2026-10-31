# Alec Tools

Unelte personale pentru **3ds Max 2027**, scrise în MAXScript și Python (PySide6) și făcute cu ajutorul AI-ului. Le folosesc prin butoane și shortcut-uri, într-un flux de lucru cu V-Ray și Arnold.

Cod personal, fără garanții. Se schimbă des.

## Uneltele

Toate apar în **Customize User Interface** la categoria **Alec Tools**, de unde le legi la un shortcut sau la un buton. Unele deschid un *caddy*: o fereastră mică cu preview live și butoanele OK / Cancel.

### Vizibilitate și materiale

| Unealta | Ce face |
| --- | --- |
| **Smart Hide**, **Smart Hide Unsel**, **Smart Unhide** | Ascunde selecția, ascunde tot ce nu e selectat, afișează tot. Merge la nivel de obiect și pe sub-obiecte (Editable Poly, Edit Poly, Editable Mesh, Edit Mesh, spline-uri). |
| **Get Materials** | Pune materialele obiectelor selectate în Slate Material Editor, pe tab-ul „Get Materials". |
| **Match Material** | Copiază materialul unui obiect ales pe obiectele selectate, într-un singur pas de undo. |

### Poziționare

| Unealta | Ce face |
| --- | --- |
| **Mid Between** | Mută selecția astfel încât centrul ei să cadă la mijlocul unor puncte. Click: alegi punctele (cu snap sau din pivoturile unor obiecte), click dreapta aplică. Shift+Click: la fel, dar cu caddy. Un dummy roșu arată unde ajunge centrul. |
| **Distribute** | Distribuie obiectele selectate pe o axă, cu pași egali între puncte de referință sau cu spațiu egal între bounding box-uri. Caddy cu preview live. |
| **BBox** | Face cuști în formă de box în jurul selecției (afișate ca box, nerandate): una pentru toată selecția sau una per obiect, pe axele lumii sau pe cele locale. Caddy cu preview. |
| **Use Pivot Point Center**, **Use Selection Center**, **Use Transform Coordinate Center** | Trei butoane care comută centrul de transformare al lui Max. Cel activ apare apăsat. |

### Măsurători

Toate se opresc cu click dreapta sau Esc, iar liniile și textele dispar din viewport.

| Unealta | Ce face |
| --- | --- |
| **Measure** | Distanța dintre punctele alese cu snap, live, cu totalul. Cu Ctrl măsoară o arie și un perimetru. |
| **Measure Angle** | Unghiul dintre două linii (4 click-uri cu snap). Cu Ctrl, unghiul în World XY. Shift+Click deschide un dialog avansat (muchii, fețe, plane). |
| **Measure BBox** | Bounding box-ul obiectului de sub mouse și dimensiunile lui. Un click îl păstrează pe ecran. Ctrl schimbă între axele obiectului și cele ale lumii. |
| **Measure Clearance** | De la suprafața de sub mouse, de-a lungul normalei, până la următoarea suprafață (podea–tavan, perete–perete). Cu Ctrl, grosimea unui perete sau a unei plăci. |
| **Measure Gap** | Spațiul liber dintre bounding box-urile a două obiecte: alegi un obiect de referință, treci cu mouse-ul peste altul și vezi distanța, împărțită pe X, Y și Z. |

### Layere, iconițe, sistem

| Unealta | Ce face |
| --- | --- |
| **Move to Layer** | Popup la cursor cu arborele de layere, ca M în Blender. Click pe un nume mută selecția acolo; fără selecție face layerul curent. Poți comuta hide / freeze / render și poți filtra scriind. |
| **Icon Browser** | Iconițele livrate cu Max. Filtrezi după nume, iar un click copiază referința iconiței. |
| **Reload Alec Tools** | Reîncarcă uneltele fără să repornești Max. |
