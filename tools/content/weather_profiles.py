#!/usr/bin/env python3
"""Phase 23 (pack Phase 21): authored weather profiles and the storm schedule
rules. Writes data/weather/profiles.json (the tuning table the game reads).

Each profile gives PEAK values (0..1 unless noted):
  cloud, rain, gust (gust strength), wind (multiplier on the base wind),
  visibility (1 = clear air, lower = mist/rain haze), sea (coastal water
  response), lightning (strike activity; separate from rain on purpose).
Phases (seconds of weather time, [min, max], seeded per visit):
  approach -> onset -> build -> peak -> recovery.
  lead: lightning starts during the approach (distant thunder before rain).
  cells: peak is broken into cells with lulls (thunderstorm / severe peaks).
  bands: peak rain comes in bands with clearer gaps (passing shower).
"""
import json, os

PROFILES = {
    "clear_broken": dict(label="Clear or broken cloud", cloud=0.35, rain=0.0, gust=0.18, wind=1.08, visibility=1.0, sea=0.2, lightning=0.0,
        phases=dict(approach=[90, 160], onset=[30, 60], build=[30, 60], peak=[200, 420], recovery=[90, 160]), weight=0, min_day=1),
    "mist_drizzle": dict(label="Mist and drizzle", cloud=0.88, rain=0.24, gust=0.08, wind=0.85, visibility=0.5, sea=0.22, lightning=0.0,
        phases=dict(approach=[120, 200], onset=[50, 90], build=[60, 120], peak=[240, 480], recovery=[150, 260]), weight=16, min_day=2),
    "passing_shower": dict(label="Passing shower", cloud=0.82, rain=0.62, gust=0.32, wind=1.3, visibility=0.72, sea=0.35, lightning=0.0, bands=[45, 70],
        phases=dict(approach=[70, 120], onset=[25, 45], build=[25, 45], peak=[120, 220], recovery=[80, 140]), weight=18, min_day=2),
    "steady_rain": dict(label="Steady rain", cloud=0.96, rain=0.72, gust=0.22, wind=1.3, visibility=0.62, sea=0.45, lightning=0.0,
        phases=dict(approach=[120, 200], onset=[50, 80], build=[60, 100], peak=[300, 560], recovery=[150, 240]), weight=14, min_day=3),
    "squall": dict(label="Squall", cloud=0.92, rain=0.95, gust=0.95, wind=2.0, visibility=0.48, sea=0.8, lightning=0.15, front=True,
        phases=dict(approach=[60, 110], onset=[15, 30], build=[15, 30], peak=[60, 120], recovery=[90, 150]), weight=8, min_day=5, gap_days=2, major=True),
    "thunderstorm": dict(label="Thunderstorm", cloud=1.0, rain=0.85, gust=0.55, wind=1.6, visibility=0.55, sea=0.62, lightning=1.0, lead=True, cells=[110, 190, 60, 120],
        phases=dict(approach=[150, 240], onset=[60, 90], build=[90, 140], peak=[320, 520], recovery=[180, 280]), weight=11, min_day=4, gap_days=2, major=True),
    "severe_coastal": dict(label="Severe coastal storm", cloud=1.0, rain=1.0, gust=1.0, wind=2.35, visibility=0.38, sea=1.0, lightning=0.8, lead=True, cells=[150, 240, 35, 60],
        phases=dict(approach=[180, 260], onset=[60, 100], build=[120, 180], peak=[420, 640], recovery=[260, 380]), weight=5, min_day=9, gap_days=6, major=True, needs_prior="thunderstorm"),
}

SCHEDULE = dict(
    visits_per_day=[[0, 40], [1, 48], [2, 12]],   # [count, weight]
    first_thunderstorm_by_day=8,                  # learn ordinary thunder early
    first_major_quiet=True,                       # the first big storm is only weather
    quiet_major_share=0.4,                        # some major storms carry no horror at all
    night_share=0.35,                             # visits that start after nightfall
    contract_night_span=1200.0,                   # awake night seconds the schedule covers
    strike_rate_per_min=3.2,                      # strikes/min at lightning 1.0
    near_share_peak=0.28,                         # share of strikes that land near camp at peak
)

out = dict(version=1, generator="tools/content/weather_profiles.py", profiles=PROFILES, schedule=SCHEDULE,
           order=["clear_broken", "mist_drizzle", "passing_shower", "steady_rain", "squall", "thunderstorm", "severe_coastal"])
p = os.path.join(os.path.dirname(__file__), "..", "..", "data", "weather", "profiles.json")
with open(p, "w") as f:
    json.dump(out, f, indent=1)
print("wrote", len(PROFILES), "profiles")
