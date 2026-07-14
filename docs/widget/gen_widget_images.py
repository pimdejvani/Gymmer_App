import os, subprocess, sys

ROOT = r"C:\Users\pimde\Desktop\pimdej\gym_app_iphone\Gymmer_App\docs\widget"
HTML_DIR = os.path.join(ROOT, "html")
IMG_DIR = os.path.join(ROOT, "images")
os.makedirs(HTML_DIR, exist_ok=True)
os.makedirs(IMG_DIR, exist_ok=True)

CHROME = r"C:\Program Files\Google\Chrome\Application\chrome.exe"

HEAD = """<!doctype html><html><head><meta charset="utf-8">
<link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/@tabler/icons-webfont@3.1.0/dist/tabler-icons.min.css">
<style>
*{box-sizing:border-box;margin:0;padding:0}
body{background:#101013;font-family:-apple-system,'Segoe UI','Leelawadee UI',Tahoma,sans-serif;
display:flex;justify-content:center;align-items:center;min-height:100vh;padding:22px}
.w{width:382px;background:#000;border-radius:22px;padding:15px 17px;border:0.5px solid #242428}
.ti{font-family:'tabler-icons'!important;font-style:normal;line-height:1}
</style></head><body>"""
FOOT = "</body></html>"

# ---- page bodies (widget card inner HTML) ----
P = {}

P["1-start"] = ("""
<div class="w">
  <div style="display:flex;align-items:center;justify-content:space-between;margin-bottom:12px">
    <span style="color:#9E9EA7;font-size:12px;font-weight:500;text-transform:uppercase;letter-spacing:.5px">วันนี้ · จันทร์</span>
    <span style="color:#7DFF8A;font-size:12px;font-weight:500;display:flex;align-items:center;gap:4px"><i class="ti ti-flame" style="font-size:14px"></i> 5 วัน</span>
  </div>
  <div style="height:40px;border-radius:12px;background:#7DFF8A;color:#04120A;font-size:15px;font-weight:500;display:flex;align-items:center;justify-content:center;gap:7px;margin-bottom:10px"><i class="ti ti-player-play" style="font-size:17px"></i> START · No Routine</div>
  <div style="display:flex;align-items:center;gap:7px">
    <div style="flex:1;display:flex;gap:7px">
      <span style="flex:1;height:34px;border-radius:10px;background:#1C1C1F;border:0.5px solid #242428;color:#F5F5F7;font-size:13px;display:flex;align-items:center;justify-content:center">Push A</span>
      <span style="flex:1;height:34px;border-radius:10px;background:#1C1C1F;border:0.5px solid #242428;color:#F5F5F7;font-size:13px;display:flex;align-items:center;justify-content:center">Pull A</span>
      <span style="flex:1;height:34px;border-radius:10px;background:#1C1C1F;border:0.5px solid #242428;color:#F5F5F7;font-size:13px;display:flex;align-items:center;justify-content:center">Legs</span>
    </div>
    <span style="width:34px;height:34px;border-radius:10px;background:#1C1C1F;color:#9E9EA7;font-size:16px;display:flex;align-items:center;justify-content:center;flex:none">&rsaquo;</span>
  </div>
</div>""", 205)

def cell(name, badge_num=None):
    right = (f'<span style="width:24px;height:24px;border-radius:50%;background:#7DFF8A;color:#04120A;font-size:13px;font-weight:500;display:flex;align-items:center;justify-content:center;flex:none">{badge_num}</span>'
             if badge_num else '<i class="ti ti-circle-plus" style="font-size:21px;color:#7DFF8A"></i>')
    return f'<span style="height:50px;border-radius:10px;background:#121214;border:0.5px solid #242428;color:#F5F5F7;font-size:13px;display:flex;align-items:center;justify-content:space-between;padding:0 8px 0 12px">{name} {right}</span>'

P["2-add-exercise"] = ("""
<div class="w">
  <div style="display:flex;gap:6px;margin-bottom:8px">
    <span style="flex:1;height:32px;border-radius:9px;background:#121214;border:0.5px solid #242428;color:#9E9EA7;font-size:12px;display:flex;align-items:center;justify-content:center;gap:4px"><i class="ti ti-filter" style="font-size:12px"></i> Chest <i class="ti ti-chevron-down" style="font-size:11px"></i></span>
    <span style="flex:1;height:32px;border-radius:9px;background:#121214;border:0.5px solid #242428;color:#9E9EA7;font-size:12px;display:flex;align-items:center;justify-content:center;gap:4px"><i class="ti ti-filter" style="font-size:12px"></i> Dumbbell <i class="ti ti-chevron-down" style="font-size:11px"></i></span>
    <span style="width:32px;height:32px;border-radius:9px;background:#1C1C1F;color:#9E9EA7;font-size:15px;display:flex;align-items:center;justify-content:center;flex:none">&lsaquo;</span>
    <span style="width:32px;height:32px;border-radius:9px;background:#1C1C1F;color:#F5F5F7;font-size:15px;display:flex;align-items:center;justify-content:center;flex:none">&rsaquo;</span>
    <span style="padding:0 14px;height:32px;border-radius:9px;background:#7DFF8A;color:#04120A;font-size:13px;font-weight:500;display:flex;align-items:center;flex:none">Done</span>
  </div>
  <div style="display:grid;grid-template-columns:1fr 1fr;gap:7px">
    __CELLS__
  </div>
</div>""".replace("__CELLS__",
    cell("Incline DB Press",1)+cell("Cable Fly")+cell("Pec Deck",2)+cell("DB Fly")), 200)

def chip(label, sel=False):
    if sel:
        return f'<span style="height:34px;border-radius:8px;background:#7DFF8A;color:#04120A;font-size:12px;font-weight:500;display:flex;align-items:center;justify-content:center">{label}</span>'
    return f'<span style="height:34px;border-radius:8px;background:#121214;border:0.5px solid #242428;color:#F5F5F7;font-size:12px;display:flex;align-items:center;justify-content:center">{label}</span>'

def filter_page(chips_html):
    return """
<div class="w">
  <div style="display:flex;justify-content:flex-end;gap:6px;margin-bottom:8px">
    <span style="width:32px;height:30px;border-radius:9px;background:#1C1C1F;color:#9E9EA7;font-size:15px;display:flex;align-items:center;justify-content:center">&lsaquo;</span>
    <span style="width:32px;height:30px;border-radius:9px;background:#1C1C1F;color:#F5F5F7;font-size:15px;display:flex;align-items:center;justify-content:center">&rsaquo;</span>
    <span style="height:30px;padding:0 14px;border-radius:9px;background:#1C1C1F;color:#F5F5F7;font-size:13px;display:flex;align-items:center;gap:5px"><i class="ti ti-arrow-left" style="font-size:14px"></i> BACK</span>
  </div>
  <div style="display:grid;grid-template-columns:repeat(4,1fr);gap:6px">__CHIPS__</div>
</div>""".replace("__CHIPS__", chips_html)

muscles = [("Chest",True),("Back",False),("Shoulder",False),("Quads",False),("Hamstr",False),
           ("Biceps",False),("Triceps",False),("Glutes",False),("Calves",False),("Abs",False),
           ("Traps",False),("Forearm",False)]
equip = [("Barbell",False),("Dumbbell",True),("Cable",False),("Machine",False),("Smith",False),
         ("Kettle",False),("Band",False),("Plate",False),("EZ-bar",False),("Bench",False),
         ("Ring",False),("Body",False)]

P["3.1-filter-muscle"] = (filter_page("".join(chip(l,s) for l,s in muscles)), 210)
P["3.2-filter-equipment"] = (filter_page("".join(chip(l,s) for l,s in equip)), 210)

def stepper(val, unit):
    return f'''<div style="flex:1;background:#121214;border:0.5px solid #242428;border-radius:11px;padding:8px 5px;display:flex;align-items:center;justify-content:space-between">
      <span style="width:28px;height:28px;border-radius:7px;background:#1C1C1F;color:#F5F5F7;font-size:17px;display:flex;align-items:center;justify-content:center">&minus;</span>
      <span style="display:flex;flex-direction:column;align-items:center;line-height:1"><span style="color:#F5F5F7;font-size:19px;font-weight:500">{val}</span><span style="color:#5E5E66;font-size:9px;margin-top:2px">{unit}</span></span>
      <span style="width:28px;height:28px;border-radius:7px;background:#1C1C1F;color:#F5F5F7;font-size:17px;display:flex;align-items:center;justify-content:center">+</span>
    </div>'''

P["4-log"] = (f"""
<div class="w">
  <div style="display:flex;align-items:center;justify-content:space-between;margin-bottom:12px">
    <div style="min-width:0">
      <div style="color:#F5F5F7;font-size:15px;font-weight:500;white-space:nowrap;overflow:hidden;text-overflow:ellipsis">Incline Dumbbell Press</div>
      <div style="color:#9E9EA7;font-size:11px">ท่า 2/5 · เซ็ต 2/3 · ครั้งก่อน 22.5×9</div>
    </div>
    <span style="width:28px;height:28px;border-radius:8px;background:#1C1C1F;color:#9E9EA7;display:flex;align-items:center;justify-content:center;flex:none"><i class="ti ti-dots" style="font-size:15px"></i></span>
  </div>
  <div style="display:flex;align-items:stretch;gap:8px">
    <div style="flex:1;display:flex;gap:7px">{stepper("22.5","KG")}{stepper("9","REP")}</div>
    <span style="width:44px;border-radius:11px;background:#7DFF8A;color:#04120A;font-size:22px;display:flex;align-items:center;justify-content:center"><i class="ti ti-check"></i></span>
    <span style="width:40px;border-radius:11px;background:#1C1C1F;color:#F5F5F7;font-size:20px;display:flex;align-items:center;justify-content:center">&rsaquo;</span>
  </div>
</div>""", 175)

P["4b-rest"] = ("""
<div class="w">
  <div style="display:flex;align-items:center;justify-content:space-between;margin-bottom:12px">
    <div style="min-width:0"><div style="color:#F5F5F7;font-size:15px;font-weight:500">Incline Dumbbell Press</div><div style="color:#9E9EA7;font-size:11px">ท่า 2/5 · เซ็ต 3/3</div></div>
    <span style="width:28px;height:28px;border-radius:8px;background:#1C1C1F;color:#9E9EA7;display:flex;align-items:center;justify-content:center;flex:none"><i class="ti ti-dots" style="font-size:15px"></i></span>
  </div>
  <div style="background:#0A140C;border:0.5px solid #1E3A22;border-radius:12px;padding:12px 13px;display:flex;align-items:center;justify-content:space-between">
    <div style="display:flex;align-items:center;gap:10px"><i class="ti ti-clock" style="font-size:22px;color:#7DFF8A"></i><span style="color:#7DFF8A;font-size:26px;font-weight:500">01:30</span></div>
    <div style="display:flex;gap:6px">
      <span style="height:32px;padding:0 10px;border-radius:9px;background:#1C1C1F;color:#F5F5F7;font-size:13px;display:flex;align-items:center;gap:3px"><i class="ti ti-minus" style="font-size:13px"></i>15</span>
      <span style="height:32px;padding:0 10px;border-radius:9px;background:#1C1C1F;color:#F5F5F7;font-size:13px;display:flex;align-items:center;gap:3px"><i class="ti ti-plus" style="font-size:13px"></i>15</span>
      <span style="height:32px;padding:0 11px;border-radius:9px;background:#1C1C1F;color:#F5F5F7;font-size:13px;display:flex;align-items:center">ข้าม</span>
    </div>
  </div>
</div>""", 175)

def mrow(label):
    return f'''<div style="display:flex;align-items:center;gap:8px;margin-bottom:7px">
      <span style="width:44px;color:#9E9EA7;font-size:12px;flex:none">{label}</span>
      <span style="flex:1;height:38px;border-radius:10px;background:#121214;border:0.5px solid #242428;color:#7DFF8A;font-size:13px;font-weight:500;display:flex;align-items:center;justify-content:center;gap:5px"><i class="ti ti-plus" style="font-size:15px"></i> เพิ่ม</span>
      <span style="flex:1;height:38px;border-radius:10px;background:#121214;border:0.5px solid #242428;color:#FF5A5A;font-size:13px;font-weight:500;display:flex;align-items:center;justify-content:center;gap:5px"><i class="ti ti-minus" style="font-size:15px"></i> ลบ</span>
    </div>'''

P["5-manage"] = (f"""
<div class="w">
  <div style="display:flex;justify-content:flex-end;margin-bottom:8px">
    <span style="height:30px;padding:0 14px;border-radius:9px;background:#1C1C1F;color:#F5F5F7;font-size:13px;display:flex;align-items:center;gap:5px"><i class="ti ti-arrow-left" style="font-size:14px"></i> BACK</span>
  </div>
  {mrow("เซ็ต")}
  <div style="margin-bottom:4px"></div>
  {mrow("ท่า")}
  <div style="display:flex;gap:8px;border-top:0.5px solid #1C1C1F;padding-top:11px;margin-top:4px">
    <span style="flex:1;height:40px;border-radius:10px;background:#0A140C;border:0.5px solid #1E3A22;color:#7DFF8A;font-size:13px;font-weight:500;display:flex;align-items:center;justify-content:center;gap:6px"><i class="ti ti-player-stop" style="font-size:16px"></i> จบ session</span>
    <span style="flex:none;width:130px;height:40px;border-radius:10px;background:#1A0E0E;border:0.5px solid #3A1E1E;color:#FF5A5A;font-size:13px;font-weight:500;display:flex;align-items:center;justify-content:center;gap:6px"><i class="ti ti-trash" style="font-size:16px"></i> Discard</span>
  </div>
</div>""", 250)

for name,(body,h) in P.items():
    html = HEAD + body + FOOT
    hp = os.path.join(HTML_DIR, name+".html")
    with open(hp,"w",encoding="utf-8") as f: f.write(html)
    out = os.path.join(IMG_DIR, name+".png")
    subprocess.run([CHROME,"--headless=new","--disable-gpu","--hide-scrollbars",
        "--force-device-scale-factor=2","--default-background-color=00000000",
        f"--window-size=426,{h}","--virtual-time-budget=4000",
        f"--screenshot={out}", "file:///"+hp.replace("\\","/")],
        check=True, capture_output=True)
    print("rendered", name, "->", out)

print("DONE")
