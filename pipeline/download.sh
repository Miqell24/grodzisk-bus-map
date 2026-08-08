#!/usr/bin/env bash
# Downloads input data: two GTFS feeds, OSM networks (Overpass), MapLibre GL.
# Everything is cached — re-running only fetches what is missing.
#
# Feeds (checked 8.08.2026):
#   GPA — Związek Powiatowo-Gminny "Grodziskie Przewozy Autobusowe", the county
#         bus network around Grodzisk Mazowiecki. The operator itself publishes
#         only per-line PDFs; the machine-readable feed comes from its
#         passenger-information vendor (kiedyPrzyjedzie.pl) through the
#         zbiorkom.live open-data mirror. NO shapes.txt — routes are matched
#         from their stop sequences.
#   WKD — Warszawska Kolej Dojazdowa, the interurban railway whose western
#         terminus is Grodzisk Mazowiecki Radońska. Has real shapes.
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p data/gtfs-gpa data/gtfs-wkd data/osm web/vendor

fetch_gtfs() { # dir url
  if [ ! -f "$1/routes.txt" ]; then
    echo "== GTFS $1 =="
    curl -fL --retry 3 --max-time 300 -o "$1.zip" "$2"
    unzip -o "$1.zip" -d "$1"
    rm -f "$1.zip"
  fi
}
fetch_gtfs data/gtfs-gpa "https://cdn.zbiorkom.live/gtfs/warsaw-gpa.zip"
fetch_gtfs data/gtfs-wkd "https://cdn.zbiorkom.live/gtfs/pkp-wkd.zip"

# 2) OSM — roadways over the whole GPA area (1767 stops span 51.925–52.349 N,
#    20.238–20.945 E, plus margin: Lutkówka and Mszczonów in the south,
#    Sochaczew in the west, Kiełpin/Łomianki in the north, and enough of western
#    Warsaw for the P+R Al. Krakowska and Cm. Wolski termini in the east)
if [ ! -f data/osm/grodzisk.json ]; then
  echo "== Overpass (roads) =="
  Q='[out:json][timeout:900];way(51.88,20.19,52.39,21.05)["highway"~"^(motorway|trunk|primary|secondary|tertiary|unclassified|residential|living_street|service|busway|construction|motorway_link|trunk_link|primary_link|secondary_link|tertiary_link)$"];out geom;'
  ok=0
  for EP in "https://overpass-api.de/api/interpreter" \
            "https://maps.mail.ru/osm/tools/overpass/api/interpreter" \
            "https://overpass.kumi.systems/api/interpreter"; do
    echo "-- $EP"
    if curl -fsS --max-time 900 -o data/osm/grodzisk.json --data-urlencode "data=$Q" "$EP" \
       && grep -q '"elements"' data/osm/grodzisk.json; then
      ok=1; break
    fi
  done
  [ "$ok" = 1 ] || { echo "Overpass: all mirrors failed" >&2; exit 1; }
fi

# 2b) OSM — rails for the WKD mode. Only the WKD corridor is needed
#     (Grodzisk Radońska → Warszawa Śródmieście WKD, plus the Milanówek Grudów
#     branch), so the bbox is much tighter than the road one. WKD is tagged
#     railway=rail (operator "Warszawska Kolej Dojazdowa", usage=branch) — the
#     query cannot filter by operator, because ~25% of the WKD ways carry no
#     operator tag and the graph would fall apart at those gaps. That pulls in
#     PKP line 1 running parallel 0.7–1.5 km to the north as well; harmless,
#     since the WKD shapes are real and Viterbi never has to guess.
if [ ! -f data/osm/grodzisk-rail.json ]; then
  echo "== Overpass (rails) =="
  QT='[out:json][timeout:300];way(52.06,20.58,52.26,21.05)["railway"~"^(rail|light_rail)$"];out geom;'
  ok=0
  for EP in "https://overpass-api.de/api/interpreter" \
            "https://maps.mail.ru/osm/tools/overpass/api/interpreter" \
            "https://overpass.kumi.systems/api/interpreter"; do
    echo "-- $EP"
    if curl -fsS --max-time 300 -o data/osm/grodzisk-rail.json --data-urlencode "data=$QT" "$EP" \
       && grep -q '"elements"' data/osm/grodzisk-rail.json; then
      ok=1; break
    fi
  done
  [ "$ok" = 1 ] || { echo "Overpass (rails): all mirrors failed" >&2; exit 1; }
fi

# 3) MapLibre GL (vendored, no CDN at runtime)
if [ ! -f web/vendor/maplibre-gl.js ]; then
  echo "== MapLibre GL =="
  curl -fL --retry 3 -o web/vendor/maplibre-gl.js  https://unpkg.com/maplibre-gl@5.6.1/dist/maplibre-gl.js
  curl -fL --retry 3 -o web/vendor/maplibre-gl.css https://unpkg.com/maplibre-gl@5.6.1/dist/maplibre-gl.css
fi

echo "OK — data ready:"
du -sh data/gtfs-gpa data/gtfs-wkd data/osm/grodzisk.json data/osm/grodzisk-rail.json 2>/dev/null || true
