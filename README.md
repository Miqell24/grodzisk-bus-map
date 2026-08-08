# Grodzisk Mazowiecki Region Public Transport — interactive map

Interactive, poster-grade map of the public transport network around **Grodzisk
Mazowiecki**: the GPA county bus network and the WKD railway — 66 lines /
~2 440 km of routes drawn along the real street and track geometry.

The GPA network is far bigger than the town it is named after. It reaches
Milanówek, Podkowa Leśna, Brwinów, Pruszków, Piastów, Żabia Wola, Nadarzyn,
Baranów, Jaktorów, Błonie, Ożarów Mazowiecki, Leszno, Kampinos, Izabelin and
Łomianki, out to Sochaczew in the west, Mszczonów in the south and the western
edge of Warsaw (P+R Al. Krakowska, Cmentarz Wolski) in the east.

## Running it

```bash
npm run download   # two GTFS feeds + OSM extracts (Overpass) + MapLibre GL
npm run build      # map matching → GeoJSON in data/out/  (~35 s)
npm run serve      # http://localhost:8139
```

Not published anywhere yet — this map is local only.

## Data

| mode | feed | lines | shapes |
|---|---|---|---|
| buses | GPA (Związek Powiatowo-Gminny "Grodziskie Przewozy Autobusowe") via the zbiorkom.live mirror of the operator's kiedyPrzyjedzie.pl export | 65 (0–98, C1, Z67) | none — matched from stop sequences |
| railway | WKD (Warszawska Kolej Dojazdowa) | 1 | full |

The operator itself publishes only per-line PDFs, so the machine-readable feed
comes from its passenger-information vendor. Two gaps in that export shape the
pipeline:

* **No `shapes.txt`.** Every route is matched from its stop sequence
  (pseudo-matching), so a badly placed pole does not merely draw a dot in the
  wrong spot — it drags the whole line into a detour. `STOP_FIX` in
  `pipeline/build.mjs` is where such poles get corrected; it is still empty.
* **`direction_id` is present but empty on all 3884 trips.** The usual
  line+direction split would collapse both directions into one representative
  and leave half of every one-way pair undrawn, so the direction key falls back
  to `trip_headsign` (see `dirKey` in `MODES`). 65 lines yield 137
  representatives — lines with short-turn variants contribute one each, which
  widens street coverage rather than hurting it.

The WKD rides the engine's *metro* slot: a wide ribbon in the operator's purple
(`#A518A3`, straight from `routes.txt`), full station discs and always-on
station names. It runs on its own right of way with 26 proper stations, so the
tram styling would undersell it. Its `WKD ZKA` rail-replacement bus is dropped
by the `route_type` filter — otherwise it would be map-matched onto the railway
graph.

## Quality

Median match error **5.1 m** across the 139 representatives (p90 6.4 m, worst
8.5 m). The WKD matches to **1.0 m** — the surveyed track geometry in its feed
lines up with OSM almost exactly.

Stop discs are half circles whose flat edge lies along the street and whose
bulge points to the pole's side of the roadway. The side comes from the pole
coordinate, and it is only discarded — for the right-hand rule, doors opening
to the right of travel — when the pole sits within `AXIS_NOISE` of the axis and
therefore says nothing. That constant is **1.5 m here, not the 6 m the sibling
cities use**: those were tuned on wide urban avenues, while this network runs
on rural roads where poles sit 3–6 m from the centerline (median 4.8 m). At
6 m the side signal was thrown away for 1265 of 1755 poles and 15% of the
two-pole stops faced the same way; at 1.5 m that is 1%.

Known rough edges:

* **Three straight chords, 141–338 m**, on lines 32, 33, 51 and 83 where they
  cross the S8 expressway near Żabia Wola, Siestrzeń and Mszczonów. The router
  finds no legal path through the interchange there and draws the gap straight.
* **Six two-pole stops still face the same way** (Czubin, Radzików and four
  others) — there the feed itself puts both poles on the same side of the road,
  9–10 m out, so there is nothing to read.
* The rail extract deliberately carries **PKP line 1** as well as the WKD (a
  quarter of the WKD ways lack the `operator` tag, so the Overpass query cannot
  filter by operator without breaking the graph). Harmless in practice: the two
  run 0.7–1.5 km apart and the WKD shapes are real, so Viterbi never has to
  guess.

## Pipeline

`npm run download` fetches both feeds, OSM roadways (Overpass, bbox
51.88–52.39 N / 20.19–21.05 E) and the WKD rail corridor. `npm run build`
map-matches every line (HMM/Viterbi on the OSM graph) and writes GeoJSON to
`data/out/`. `npm run serve` hosts the map at http://localhost:8139.

Data: GPA (Grodziskie Przewozy Autobusowe) · WKD · base map © OpenFreeMap /
OpenMapTiles / OpenStreetMap contributors.
