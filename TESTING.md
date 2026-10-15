# Test plan for this pass (run on the Mac)

## 1. Get it compiling (about 10 minutes)
```bash
cd mobile
flutter pub get          # pubspec dropped unused riverpod, build_runner, google_fonts
dart format lib          # tidies indentation in edited blocks
flutter analyze          # fix anything red before going further
```
Errors at this step are the main risk of this pass: no compiler was available while editing. Most will be small, like a named parameter or a type. Paste the output to Claude if you want them fixed.

## 2. Database, before the app talks to it
Read `supabase/CHANGES_2026-10-13.md` first. Order matters:
```bash
supabase db push                                   # migrations 20261013170000 to 170600
supabase functions deploy create-booking-request   # only AFTER db push
```
Migration 170200 stops on purpose if any trainer already has overlapping confirmed sessions. It lists the overlapping pairs; fix those rows, then push again. Try it on staging first.

## 3. Run it
Android phone sign-in: add the debug SHA-1 and SHA-256 (`cd android && ./gradlew signingReport`) in the Firebase console first, or sign-in falls back to a reCAPTCHA browser step.

```bash
flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_PUBLISHABLE_KEY=...
```
Without these two values the app now stops with a clear message instead of a blank screen.

## 4. Walk through these on a real phone (iOS and Android)
**Sign in**
- [ ] Phone entry: tapping outside the field does NOT send a code; Done and the button do
- [ ] The code arrives by SMS, and every screen says SMS
- [ ] Wrong code: boxes turn red and the screen counts down tries left
- [ ] "Didn't get the code?" leads to resend and to "use a different number"
- [ ] "Not you? Use a different number" signs you out; reopening the app doesn't log you back in
- [ ] Kill the app on Your details, reopen it: you land on Your details, not Home
- [ ] Terms and Privacy links on sign-up open as a sheet

**Help me choose**
- [ ] All 4 steps; step 1 has an X, later steps have Back
- [ ] Submit while a request is already open: you see the open-request screen, not an error
- [ ] Same goal plus a new note: 3.6 shows "We added your new note to it"

**Matching**
- [ ] Your match within budget and above budget; "Not quite right?" sends once
- [ ] Nobody fits yet: picking a change sends the request back to matching. To set it up in Supabase, put the request on `status = 'matched'`, `match_outcome = 'no_fit'`, `trainer_id = null`

**Booking**
- [ ] Session, then Location, then Time, then Review: amounts read "AED 262.50", never "250.0"
- [ ] Times are 12-hour Dubai time even with the phone set to another time zone
- [ ] Two phones book the same trainer and slot: the second gets "Slot taken" (6.3) with alternative times (only after step 2: the live booking function has no slot check yet)
- [ ] Book again from Past skips straight to Time and ends on "Booked again"
- [ ] Signing in from "Sign in to book" brings you back to the booking

**Sessions**
- [ ] Upcoming, Past and Requests, including their empty states
- [ ] A session in progress stays visible during its hour
- [ ] Move 24h or more ahead is free, and only once. Inside 24h shows the pay-to-move sheet, then "Payment isn't available yet" (until Tap)
- [ ] Cancel shows the refund in dirhams; the cancelled card shows the same amount days later

**Trainers**
- [ ] Every trainer appears with no filters on, including anyone above AED 400
- [ ] A broken photo shows initials, never a broken image

**Profile**
- [ ] Add a photo with the camera on iPhone: you get a permission prompt, not a crash
- [ ] Change number, then 12.2f "Changed just now" line
- [ ] Log out sheet; the delete-account states (with and without a booked session)

**Push**
- [ ] Right after signing in, the app asks once to allow notifications
- [ ] A notification arrives on iPhone. Push and Background Modes are already set in the project; the only missing piece is uploading the APNs key in the Firebase console
- [ ] On a real iPhone, sign with the paid Apple Developer team. A free personal team cannot sign apps that use push.

**15 Oct additions**
- [ ] Bell in the Home header opens Notifications; the lime dot disappears once everything is read
- [ ] Help & support: search, Expand all, WhatsApp and email buttons
- [ ] Legal screens show "Arabic" with "Coming soon", and it does nothing when tapped
- [ ] Trainers: turn on any filter, see "Showing N of M trainers" and "Clear all"; Clear all resets the toggle, chips and Filters count
- [ ] Every sheet (What we checked, Filters, Log out, profile photo, cancel and move sheets, Terms during sign-up): drag down on the middle of it to close; a short drag springs back
