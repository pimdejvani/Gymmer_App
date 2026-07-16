# GYMMER — iOS Widget และ Lock Screen Live Activity

สถานะ: implementation ใช้งานได้บน branch `ios` (ตรวจล่าสุด 2026-07-16)

เอกสารนี้อธิบายโค้ดจริงของ companion บน iOS ไม่ใช่แผน mockup เดิม โดยมี
สอง surface ที่ใช้ App Intents และ state ชุดเดียวกัน:

- Home Screen WidgetKit widget: ขนาด **Medium (4×2)** เท่านั้น
- Live Activity: Lock Screen และ expanded Dynamic Island ใช้หน้า Add / Filter /
  Log / Rest / Manage ชุดเดียวกับ widget โดยตัดเฉพาะหน้า Start
- Configurable System Control: เพิ่ม control ซ้ำได้แล้วเลือก KG/REP
  +/−, Complete Set, Next Exercise หรือ Skip Rest สำหรับ Control Center,
  ช่องปุ่ม Lock Screen และ Action button
- HealthKit บน iOS 26+: session แบบ traditional strength เริ่ม/จบพร้อม Gymmer

Runner, Widget extension และ XCTest ตั้ง deployment target เป็น iOS 26.0
ตรงกัน. Flutter app ยังเป็นแอปหลักและยังรองรับ Android/web ในฐานะ
dev stand-in; companion นี้ทำงานเฉพาะ iOS

## ภาพรวมสถาปัตยกรรม

```text
Flutter app
  ├─ WidgetBridge (Dart)
  │    └─ MethodChannel gymmer/widget
  ├─ SQLite = durable source of truth
  └─ AppDelegate.swift
       └─ App Group container
            ├─ catalog.json       → exercise picker
            ├─ routines.json      → Start page
            └─ session.json       ↔ active session

GymmerWidget.swift
  ├─ reads the three JSON snapshots
  ├─ Home-widget AppIntents mutate session.json in the extension
  └─ LiveSync.refresh(activityID:) updates the explicitly targeted Activity

GymmerWidget.swift backend + GymmerNavigationIntent.swift (Runner + Widget target)
  └─ LiveActivityIntent wrappers call the same mutations in the app process

Flutter resumes
  └─ reads a newer widget-authored session.json revision → rebuilds → saves SQLite

HealthWorkoutManager.swift (iOS 26+)
  └─ Gymmer start/finish/discard ↔ HKWorkoutSession + HKLiveWorkoutBuilder
```

App Group id ไม่ควร hard-code ตอนติดตั้งจริง เพราะ SideStore อาจ rewrite id
ระหว่าง re-sign. Runner และ extension จึงอ่าน id ที่ได้รับจริงจาก embedded
provisioning profile แล้วใช้ resolver เดียวกัน โดยมี
`group.com.gymmer.gymmerFlutter` เป็น fallback สำหรับ dev/simulator

## State contract

| ไฟล์ | ผู้เขียนหลัก | เนื้อหา |
|---|---|---|
| `catalog.json` | Flutter | exercise name/muscle/equipment และ set ล่าสุดสำหรับ autofill |
| `routines.json` | Flutter | routine name/group และ exercise + set template เต็มชุด |
| `session.json` | Flutter + widget | active workout, current page/exercise/set, rest timer และ outcome |

Flutter เขียน `session.json` ด้วย `by: "app"` และ `rev` จาก microseconds ส่วน
widget เขียนด้วย `by: "widget"` และสร้าง `rev` ใหม่ทุก mutation. เมื่อแอป
กลับมา foreground จะ reconcile เฉพาะ revision ที่ใหม่กว่า revision ล่าสุดที่
แอปเขียนเอง:

- `active: true` → สร้าง `ActiveWorkout` ใหม่จาก catalog แล้วบันทึก draft ลง
  SQLite
- `active: false`, `outcome: "finish"` → สร้าง workout แล้วส่งผ่าน
  `finishWorkout`
- `active: false`, `outcome: "discard"` → ล้าง active draft โดยไม่บันทึก history

ชื่อ exercise ถูก match กับ catalog เพื่อคืน media/secondary muscles; ถ้าไม่
พบจะใช้ exercise แบบ minimal จากข้อมูลใน JSON. บน platform ที่ไม่มี native
channel การเขียน/อ่านจะ no-op และแอปหลักยังทำงานตามปกติ

## Home Screen Widget — หน้าจริง

ทุก action เป็น App Intent. Home Screen widget ใช้ `AppIntent` ปกติใน extension
เหมือน implementation เดิม ส่วน Live Activity เลือก intent คนละ type:
`LiveActivityIntent` wrapper ที่รันใน Runner แล้ว dispatch เข้า mutation ชุด
เดียวกัน การแยก type ทำให้ widget ไม่ถูกย้ายไปรันใน app process และยังคง
response path เดิมไว้ ทั้งสองทางจบที่ `WStore.saveAndSync`: save, refresh Live
Activity และ reload widget timeline

ปุ่มบน Live Activity ครอบคลุม Add, Filter, Log, Rest และ Manage โดยไม่รวม Start

### 1. Start

- `START · No Routine` สร้าง session เปล่าและเปิดหน้า Add
- routine card เริ่ม routine พร้อม exercise/set template เต็มชุดและไปหน้า Log
- pager แสดง routine เป็นชุด ๆ; ไม่มี routine จะแสดงคำแนะนำให้เพิ่มจากแอป

### 2. Add exercise

- exercise แสดงเป็นกริด 2×2, 4 ช่องต่อหน้า
- แตะ exercise ที่ยังไม่เลือกเพื่อเพิ่ม 1 set และ seed KG/REP จาก history ล่าสุด
- exercise ที่เลือกแล้วแสดงลำดับและจำนวน set เช่น `1x3`
- แตะ badge ลด set; แตะส่วนชื่อเพิ่ม set โดย copy ค่าจาก set ล่าสุด
- ลบ set สุดท้ายจะนำ exercise ออกจาก queue
- `Done` ไปหน้า Log; pager มีปุ่มขวาปุ่มเดียวและวนกลับหน้าแรกเมื่อถึงท้าย

### 3.1 / 3.2. Filters

- filter กล้ามเนื้อและอุปกรณ์แยกคนละหน้า
- แสดง chip เป็นกริด 3×3 รวมช่อง `All`; ถ้ามีค่ามากจะแบ่งเป็นหลายหน้า
- filter ที่เลือกใช้สี accent และ reset list กลับหน้าแรก
- `BACK` กลับหน้า Add

### 4. Log

หน้าหลักไม่มี text input จึงใช้ stepper:

- REP: ลด/เพิ่มทีละ 1
- KG: ลด/เพิ่มทีละ 2.5
- ปุ่ม `›` ไป exercise ถัดไป
- ปุ่ม `✓` complete set และเลื่อนไป set/exercise ถัดไปตามลำดับ
- `…` เปิด Manage
- เมื่อทุก set ครบจะแสดง `จบ session`

### 4b. Rest

- complete set จะเริ่ม rest ตาม `rest` ของ exercise (default 90 วินาที)
- `−15` / `+15` ปรับเวลาที่เหลือทีละ 15 วินาที
- `ข้าม` ยกเลิก rest; ถ้าเป็น set สุดท้ายจะแสดง `จบ session`
- countdown ใช้ SwiftUI `Text(timerInterval:)` จึงไม่ต้องสร้าง timeline
  รายวินาทีที่อาจชน WidgetKit refresh budget
- เมื่อ rest หมดจะมี local notification หนึ่งรายการชื่อ `พักครบ 💪` พร้อมเสียง
  ซึ่งเป็นวิธีที่ใช้แทน background haptic-only API ของ iOS

### 5. Manage

- เพิ่ม/ลบ set ของ exercise ปัจจุบัน
- เพิ่ม exercise ผ่านหน้า Add หรือลบ exercise ปัจจุบัน
- กลับ Log
- `จบ session` และ `Discard`

## Lock Screen Live Activity

Live Activity ถูกประกาศใน `GymmerWidget` bundle และใช้
`GymmerActivityAttributes` ที่ compile เข้า **ทั้ง Runner และ extension**.
หน้าใน Live Activity อ่าน `session.json`/`catalog.json` แล้วส่งเข้า
`GymmerSessionPagesView` ชุดเดียวกับ Home Screen Widget จึงไม่ควรมี layout หรือ
component แยกจาก widget เว้นแต่ข้อจำกัดของ ActivityKit บังคับ

วงจรชีวิตแบ่งตามข้อจำกัดของ ActivityKit:

1. Flutter foreground เรียก `startLiveActivity` เมื่อมี active workout; ถ้ามี
   activity อยู่แล้วจะ update แทนการสร้างซ้อน
2. การแก้ draft จากแอปส่ง state ปัจจุบันไป Runner เพื่อ update
3. ทุกปุ่มบน Live Activity รัน wrapper `LiveActivityIntent` ใน Runner process,
   แล้วเรียก mutation เดียวกับ widget เพื่อเขียน `session.json` และ update
   ActivityKit content state โดยรับ `context.activityID` และเลือก Activity
   ตรง ID แทนการวนแก้ทุก Activity
4. หลัง Activity update สำเร็จจึง reload Home Screen widget timeline; KG/REP
   ไม่ใช้ invalidation feedback หรือ numeric transition เพราะทำให้เกิดการกระพิบ
5. finish/discard เรียก `endLiveActivity` และปิด activity แบบ immediate

finish/discard ใช้ terminal flow แยก: บันทึก outcome และขอ reload Home Widget
ก่อนรอ ActivityKit end เพื่อไม่ให้ปุ่มค้างถ้า ActivityKit ตอบช้า และตอน cold
launch Flutter จะ reconcile terminal revision ก่อนเขียน draft จาก SQLite กลับ
ลง App Group จึงไม่ทำให้ session ที่จบแล้วฟื้นกลับมา

State ที่แสดงคือชื่อ routine/session, exercise ปัจจุบัน, `ท่า n/m`, set label,
KG, REP และ previous. มีสาม phase:

- `add`, `fmuscle`, `fequip`, `log`, `manage` — ใช้ page router เดียวกับ widget
- `rest` — แสดงจาก `LogView` เมื่อ countdown ทำงาน
- `done` / `restdone` — ปุ่ม finish ตาม state ของ widget

Lock Screen ใช้ layout สูงประมาณ 158pt. Dynamic Island แบบ compact/minimal แสดง
ข้อมูลย่อ; เมื่อกดค้างให้ expanded presentation ซึ่ง reuse หน้าชุดเดียวกับ
Lock Screen. iPhone ที่ไม่มี Dynamic Island ไม่มี Live Activity แบบ persistent
ตอนปลดล็อก จึงต้องใช้ Home Screen widget หากต้องการกดได้ตลอดโดยไม่ล็อกจอ

Activity intents ตั้ง `authenticationPolicy = .alwaysAllowed` แต่เอกสารของ
Apple ระบุว่าปุ่ม/สวิตช์ของ Widget และ Live Activity จะ inactive ขณะเครื่อง
ล็อกจนกว่าจะปลดล็อก; แอป override policy นี้ไม่ได้. ปุ่มของ YouTube เป็น
system Now Playing controls สำหรับ media playback ซึ่งเป็นคนละ API. เส้นทาง workout ที่
ระบบรองรับโดยตรงจึงใช้ System Controls ด้านล่างร่วมกับ HealthKit session

### System Controls (iOS 18+)

รายละเอียด implementation ปัจจุบันและ design ที่วางแผนเพิ่ม dynamic KG/REP
อยู่ใน [`SYSTEM_CONTROLS.md`](SYSTEM_CONTROLS.md). Design ดังกล่าวยังไม่
implement และไม่เปลี่ยนสถานะของ Control ที่อธิบายด้านล่าง

Widget bundle ประกาศ `GymmerWorkoutActionControl` รายการเดียวด้วย
`AppIntentControlConfiguration`. ผู้ใช้เพิ่มได้หลาย instance แล้วกำหนดแต่ละ
อันเป็น KG +2.5, KG −2.5, REP +1, REP −1, Complete Set, Next Exercise หรือ
Skip Rest. ตัว action reuse `AppIntent` เส้นทางเดียวกับ Home Widget พร้อม
`alwaysAllowed` และ background-only mode. ระบบแสดง control นี้ใน Control Center,
ช่องปุ่ม Lock Screen
หรือ Action button; พื้นที่ Lock Screen มีจำนวนช่องจำกัด จึงไม่แทนหน้าเต็มของ
Live Activity

ค่า KG/REP ใน Live Activity อ่านจาก `ActivityViewContext.state` โดยตรงและทำ
เครื่องหมาย `invalidatableContent` เฉพาะ surface นี้ จึงใช้สถานะเบลอมาตรฐาน
ระหว่างรอผลปุ่มโดยไม่เปลี่ยน feedback ของ Home Widget. การ mutation จาก Live
Activity อัปเดต Activity ID ที่กดก่อนขอ reload Home Widget; เส้นทาง Home Widget
ยังคง reload-first เหมือนเดิม

### HealthKit workout session (iOS 26+)

เมื่อเริ่ม workout จาก Flutter แอปจะขอสิทธิ์เขียน workout แล้วสร้าง
`HKWorkoutSession` ประเภท `.traditionalStrengthTraining` แบบ indoor พร้อม
`HKLiveWorkoutBuilder`. Finish ใช้ `stopActivity`, จบ collection และบันทึก
workout ลง HealthKit; Discard เรียก `discardWorkout` โดยไม่สร้าง record.
`SceneDelegate` รองรับ active-workout recovery และต่อ delegate กลับเมื่อ iOS
เปิด process ใหม่. หากเครื่องปฏิเสธสิทธิ์ HealthKit ยังใช้ Gymmer/widget/Live
Activity ได้ตามเดิม และไม่มี voice intent extension หรือ shortcut provider

## ไฟล์ implementation

| ไฟล์ | หน้าที่ |
|---|---|
| `gymmer_flutter/lib/data/widget_bridge.dart` | serialize catalog/routines/session, Live Activity state, HealthKit lifecycle bridge, อ่านกลับและ rebuild workout |
| `gymmer_flutter/ios/Runner/AppDelegate.swift` | MethodChannel, App Group I/O, ActivityKit manager และ HealthKit start/stop bridge |
| `gymmer_flutter/ios/Runner/HealthWorkoutManager.swift` | iOS 26 HealthKit session/builder start, save, discard และ recovery |
| `gymmer_flutter/ios/Runner/SceneDelegate.swift` | HealthKit active-workout recovery + temporary App Group POC alert |
| `gymmer_flutter/ios/GymmerWidget/GymmerWidget.swift` | widget/Activity views, shared store/mutations, widget AppIntents, Live Activity wrapper และ Activity sync; backend compile เข้า Runner ด้วย |
| `gymmer_flutter/ios/GymmerWidget/GymmerActivityAttributes.swift` | shared ActivityKit attributes/content state |
| `gymmer_flutter/ios/GymmerWidget/GymmerNavigationIntent.swift` | shared page-navigation LiveActivityIntent ใน Runner + widget target |
| `gymmer_flutter/ios/Runner.xcodeproj/project.pbxproj` | WidgetKit target, embed extension, shared source membership |
| `gymmer_flutter/ios/Runner/Info.plist` | Live Activities, HealthKit usage text/background mode และ photo-library permission |
| `gymmer_flutter/ios/Runner/Runner.entitlements` | Runner App Group + HealthKit entitlements |
| `gymmer_flutter/ios/GymmerWidget/GymmerWidget.entitlements` | extension App Group entitlement |
| `gymmer_flutter/ios/RunnerTests/RunnerTests.swift` | native intent/control mutation tests บน temporary JSON store |

## ข้อจำกัดและรายการตรวจสอบก่อน release

- Widget รองรับเฉพาะ Medium; ไม่มี scrolling และไม่มี text/number entry
- Live Activity จะทำงานไม่ได้ถ้าผู้ใช้ปิด Live Activities หรือ OS ไม่รองรับ
- iOS อาจต้องการ Face ID/passcode ก่อนรันปุ่ม Live Activity แม้ intent ขอ
  `alwaysAllowed`; แอปไม่สามารถ override system Lock Screen policy ได้
- iPhone ที่ไม่มี Dynamic Island แสดง Live Activity แบบ persistent เฉพาะ Lock Screen
- System Controls ต้องใช้ iOS 18+ และผู้ใช้ต้องเพิ่มเข้า Control Center/Lock
  Screen/Action button เอง แอปเพิ่มให้โดยอัตโนมัติไม่ได้
- HealthKit workout session บน iPhone/iPad ต้องใช้ iOS 26+ และ provisioning
  profile ต้อง grant HealthKit; CI compile/test ไม่ยืนยันสิทธิ์หลัง SideStore
  re-sign จึงต้องตรวจบนเครื่องจริง
- CI ใช้ `macos-26`: Flutter analyze/tests, native XCTest และ release build รัน
  เป็น jobs ขนานกัน แล้ว publish เมื่อทั้งหมดผ่าน; docs-only ไม่ trigger build
- notification permission ต้องได้รับเพื่อให้ rest-end sound/vibration ทำงาน
- App Group ต้องถูก grant ให้ทั้ง Runner และ extension หลัง SideStore re-sign
- ลบ alert `App Group POC v2` จาก `SceneDelegate.swift`
- ทดสอบบนเครื่องจริง: start จากแอปและ widget, reconcile widget → แอป, complete
  set/rest, finish, discard, และการ re-sign แล้วข้อมูลเดิมยังอยู่
- Native XCTest ครอบคลุม mutation แต่ยังไม่แทนการทดสอบ Lock Screen control,
  HealthKit permission/recovery และ SideStore entitlement บนเครื่องจริง

## Mockup เดิม

ไฟล์ภาพและ HTML ด้านล่างเป็น reference ตอนออกแบบ flow; โค้ดปัจจุบันได้
implement flow แล้วและมีการปรับ layout Log/Filter ให้ตรงข้อจำกัดของ Medium:

- `images/1-start.png` ถึง `images/5-manage.png`
- `html/1-start.html` ถึง `html/5-manage.html`
- `gen_widget_images.py`

ภาพ mockup เก่าจึงไม่ใช่ source of truth สำหรับขนาดหรือสถานะ implementation;
ให้ยึด `GymmerWidget.swift` และเอกสารส่วนบนเป็นหลัก
