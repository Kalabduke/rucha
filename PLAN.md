# RUCHA — Flutter UI plan (front-end only)

Screen-by-screen UI description. No backend or data-layer work in this document.
Theme: existing dark tokens (`#0C110F` background, `#151C19` surface, coral `#FF7A42`, teal `#12A88A`, gold `#F2B705`). Cards 16 px radius, 16 px page padding, uppercase 11 px section labels.

## Shared UI rules

- Activity colours: **run coral `#FF5A1F`**, **walk gold `#F2B705`**, **ride teal `#0E8A6A`** — used on maps, badges and icons everywhere.
- Every map: OSM tiles, dark filter, start/finish pins, attribution, zoom + recenter controls.
- Every list: skeleton while loading, dedicated empty state with one action, no invented data.
- Two save verbs are always distinct: **Save to my Gallery** (in-app) vs **Download** (phone Photos).

## 1. Home

- **Header**: "Good morning, Kaleab" (or "Athlete"), full date underneath, city chip on the right, coral **Start running** button → Record.
- **Period chips**: This week · Last 7 days · 4 weeks · All. Below them a caption: "Mon 9 – Sun 15 Nov · 3 activities".
- **Four stat cards** (2×2): Distance (km), Time (h:mm), Elevation (+m), Activities. Each with a small delta line ("+12 % vs last week" / "—") and tappable → Activities.
- **Your routes card**: 280 px map with every route of the period drawn (newest solid, older faded), legend (Run/Walk/Ride), badge "3 routes · 41.2 km". Empty: "No routes in this period" + Start running.
- **Training volume card**: metric switch (Distance / Time / Elevation), Bars ↔ Line toggle, average line, today highlighted; tapping a bar opens that day's activities. Empty: "No training in this period".
- **Recent activities**: 5 rows (icon, title, km · time · city) → activity detail. Removed: hub tiles, altitude card.

## 2. Explore

- **Header**: city name + elevation pill, `Near me / All cities` toggle.
- **Map (320 px)**: area pins with activity counts and route lines at once; selected item is emphasised and fitted.
- **Popular near you card**: segmented `Areas (n)` / `Routes (n)`.
  - Area row: name, "N activities started here · city", distance away, Google Maps button. Selecting draws a **dashed line** from my position with "3.2 km direct" and fits both.
  - Route row: auto-generated name, "5.2 km · +180 m · Cat 2 · 12 attempts · CR 24:10". Selecting highlights the line.
- Route names look like "Meskel Square loop · 5.2 km", "Entoto out-and-back · 8.4 km", "Bole → Kazanchis".
- Empty: "No popular areas near you yet" + Record.

## 3. Record

- **Title block**: "Record an activity" / "Ready when you are".
- **Type selector**: Run · **Walk** · Ride (full width).
- **Name this activity** card: input, helper "Your title is saved with the exact start coordinates".
- **Live tracking card**: header + subtitle, GPS pill ("GPS strong · ±6 m"), 280 px map with "Map · 0.0 km tracked" badge, legend, scale, north arrow.
- **Metrics**: Distance, Time, Pace (Speed for Ride), Elevation, Calories, Heart Rate.
- **Primary button**: Start → Pause + Finish → Resume + Finish; "Acquiring GPS…" state.
- **Kilometre splits** table.
- **Sensors & devices**: GPS, Heart rate, Smartwatch only (real states, no fake rows).
- **Distance goal & auto-stop card (bottom)**: target km, Save goal, Start goal run, auto-stop switch, live "2.4 / 5.0 km" progress.
- Kept: Ghost of Legends as one compact row near the bottom.

## 4. Activities

- **Header**: "Activities" + "N activities · Made for Ethiopia"; filters All / Walks / Runs / Rides.
- **Challenges from other athletes** card: 3 compact rows (title, creator, target, participants) + "Open all".
- **Your challenges** card: 3 rows with status + "Open all" (or Create challenge when empty).
- **Training log**: 8-column table on wide screens (TYPE · ACTIVITY · DATE · DISTANCE · TIME · PACE · ELEV), cards on phones. No KUDOS column.
- **All-time strip**: total km, time, climb, sessions.
- Tap row → activity detail. "Open all" → All / Mine / Others list → challenge detail with leaderboard (rank, athlete, result, ✓ completed, "You" row), participants count, Join, Time trial.

## 5. Community

- **Popular communities card**: top 5 by members — colour dot, name, city, "128 members", Public/Friends pill, Join / Requested / Joined.
- **Friends card**: title "Friends (n)" with a **Friend requests** button (badge count) top-right; avatar row; tap a friend → sheet with their challenges for you (1v1 duels) and "Challenge them".
- **Your communities**: rows with owner/Requests badge → community; **+ Create community**.
- **Create form**: name, purpose, city, focus (Run/Walk/Ride/Mixed), colour swatches, **Public / Friends only**, **Anyone / Ask me first**.
- **Inside a community**: header (name, city, members, visibility); tabs Challenges · Channel · Group · Members · Requests.
  - Challenges: approved only; owners/admins see a Pending segment with Approve / Decline.
  - Requests: athlete rows with Accept / Decline.
- Offline: "Communities need the RUCHA server" — never sample clubs.

## 6. Gallery

- **Header**: "Your Gallery" + "Run cards saved and ready to post · N card"; **Create a run card**.
- **Card grid**: 2 columns on phones, 4:5 card art with the route drawn, title, "25.43 km · 53:24 · Hawassa", then **View · Download · Share · Delete · Create segment**.
- **Choose a run modal**: search + activity rows (icon, title, date, km); activities without a route show "No GPS route to draw" and are disabled.
- **Create segment sheet**: prefilled name, auto category, distance/climb/type, confirm → "View in Segments".
- Empty: "No cards yet" + Create a run card.

## 7. Segments & Profile

- **Segments**: cards with route thumbnail, name, city, "5.2 km · +180 m · Cat 2", CR strip, attempts; floating **Create segment** from an activity.
- **Profile**: avatar + name, all-time stat grid, best efforts (1 km / 5 km / 10 km / half — runs only), weekly volume chart, server settings, account & privacy, sign out.
