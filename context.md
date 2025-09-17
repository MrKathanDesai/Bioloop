You are helping build **Bioloop**, a health and wellness iOS app inspired by Whoop and Bevel. It uses **real Apple Watch and HealthKit data** to present users with **4 core scores** (Recovery, Sleep, Strain, Stress), alongside journaling, breathing exercises, symptom tracking, and time-based health analytics.

Bioloop is designed to serve both **casual users** (via simple summaries) and **power users** (via deep insights). All metrics must be accurate — **never simulate or generate fake data**. If data is missing, show “Data Unavailable.”

---

# 🔧 TECH STACK
- SwiftUI (Modern, Native UI)
- HealthKit (Apple Watch Data)
- CoreData (Local journal, symptom logs)
- Swift Charts (for trend graphs)
- MVVM architecture
- Optional: CoreML for local AI insights

---

# 🧭 APP FLOW OVERVIEW

1. **Onboarding**: Permissions, Health Condition, Goal, Notification Preferences  
2. **Daily Flow**:
   - Wake Detected → Breathing Exercise + Symptom Check
   - Home Screen shows core scores
   - Journal reminder at end of day
3. **Weekly Flow**:
   - Weekly wellness summary (composite)
   - Recommendations via AI

---

# 🏠 HOME DASHBOARD

Displays 4 cards with daily scores:

### Each Score Card Shows:
- Icon + Title (Recovery, Sleep, etc.)
- Daily Score (0–100)
- Status: Green / Yellow / Red
- Mini 7-day trend line

👉 **Tapping a card reveals a full-screen detail view**:
- Large metric value
- Full explanation: what it means
- Key sub-metrics with value + line chart
- Color zones (e.g., optimal HRV range)
- Data availability message if missing

This structure ensures beginner users get a quick summary, while advanced users get all the context they want.

---

# 🔍 SCORE LOGIC (Detail Page per Score)

### ✅ Recovery
- Inputs: HRV, Resting HR, Sleep Efficiency
- Subcards: HRV vs baseline, RHR trend, sleep impact
- AI Insights: “Low HRV today — consider resting”

### 😴 Sleep
- Inputs: Duration, Efficiency, Latency, Wake Events
- Subcards: REM/Deep (if available), bedtime variance, sleep consistency
- AI: “You’re sleeping 45 min less on avg on weekends”

### 🏃 Strain
- Inputs: HR Zone Minutes, Energy Burned, Workout Intensity
- Subcards: Optimal vs Actual Strain, zone breakdown
- AI: “You’re undertraining 20% relative to your recovery”

### 🔥 Stress
- Inputs: HRV Fluctuations, Symptom Logs, Breathing Data
- Subcards: Stress triggers, breathing compliance
- AI: “High caffeine + no breathing practice = 18% spike in stress last 3 days”

Each detailed view contains:
- Swift Charts Line Graph (7D, 30D, 90D toggle)
- Summary Stats
- Contextual AI Insight

---

# 🌿 BIOLOGY TAB

Displays vitals + daily health calendar

### Data Cards:
- Weight
- Body Fat %
- HRV Baseline
- RHR Baseline
- SpO2
- VO2 Max
- Blood Pressure / Glucose (if available)

### GitHub-Style Daily Grid:
- Green boxes for days with optimal recovery/sleep/strain
- Tap a box to view full day summary (all scores + journal entries)

---

# 📝 JOURNALING TAB

User logs lifestyle data:
- Caffeine, Alcohol, Tobacco, Late Meals
- Supplements, Sleep Environment, Room Temp
- Custom free text
- Timestamped

Use toggle chips and a text field. Store with CoreData. Tracked for ML pattern detection.

---

# 🌬️ BREATHING + SYMPTOM FLOW

Triggered automatically after wake detection or manually:

1. **Breathing Animation** (5.5s inhale/exhale × 4 rounds)
2. **Symptom Form**:
   - Mood Slider
   - Checklist (fatigue, headache, soreness, etc.)
   - Optional text input

All logs are timestamped and shown in Symptom History.

---

# 🏋️ FITNESS TAB

Displays physical performance stats:
- VO2 Max
- Max HR, RHR
- Activity Ring Stats
- HR Zone Time Breakdown
- Workout Timeline

Show line graphs with colored heart rate zones.

---

# 📅 WEEKLY WELLNESS SCORE

Aggregated from:
- Avg. Recovery
- Sleep Consistency
- Strain Efficiency
- Symptom burden
- Breathing practice consistency

Show:
- Weekly Score (0–100)
- Comparison with last week
- Chart (week-over-week)
- Recommendations summary

---

# 🔁 PATTERN DETECTION AI (Optional ML)

Detect correlations:
- “Your recovery drops 20% after late meals”
- “Higher HRV follows cold baths”

Run locally or sync logs to server for secure processing.

---

# 👤 ONBOARDING FLOW

Ask user:
- Health Goals: (e.g. Fat Loss, Energy, Longevity)
- Health Conditions: Diabetes, BP, IBS, PCOS, etc.
- Notification Preferences (Breathing, Journaling)
- HealthKit permissions

---

# 📊 UI STANDARDS

- All modules use line graphs (via Swift Charts)
- Score cards show summary by default
- Detailed pages expand on tap
- GitHub-style daily grid in Biology Tab
- Fallback UI: “Data unavailable” when HealthKit data missing

---

# 🧱 FILE STRUCTURE
