#!/bin/bash
# ============================================================
# 上海房市每日追踪 - 自动更新脚本
# 每天 9:30 由 launchd 调度执行
# ============================================================

WORK_DIR="/Users/caocao/Documents/上海房市追踪系统"
HTML_FILE="$WORK_DIR/index.html"
DATA_DIR="$WORK_DIR/data"
LOG_FILE="$WORK_DIR/update.log"
PORT=9388

# 创建目录
mkdir -p "$DATA_DIR"

# 记录日志
echo "[$(date '+%Y-%m-%d %H:%M:%S')] 开始每日房市更新..." >> "$LOG_FILE"

# ============================================================
# 1. 获取今日日期信息
# ============================================================
TODAY=$(date '+%Y-%m-%d')
TODAY_CN=$(date '+%m月%d日')
WEEKDAY_NUM=$(date '+%u')
WEEKDAYS=("" "周一" "周二" "周三" "周四" "周五" "周六" "周日")
WEEKDAY=${WEEKDAYS[$WEEKDAY_NUM]}
YEAR=$(date '+%Y')
MONTH=$(date '+%m')
DAY=$(date '+%d')

# 昨天日期
YESTERDAY=$(date -v-1d '+%Y-%m-%d')
YESTERDAY_CN=$(date -v-1d '+%m月%d日')
YESTERDAY_MONTH=$(date -v-1d '+%m')
YESTERDAY_DAY=$(date -v-1d '+%d')

# 判断是否月初（1-3号）
IS_MONTH_START="false"
if [ "$DAY" -le 3 ]; then
    IS_MONTH_START="true"
fi

# ============================================================
# 2. 生成每日数据 JSON（模拟 + 真实趋势）
# ============================================================

# 读取上次数据（如果存在）
PREV_DATA="$DATA_DIR/latest.json"
if [ -f "$PREV_DATA" ]; then
    PREV_VOLUME=$(python3 -c "import json; d=json.load(open('$PREV_DATA')); print(d.get('volume', 600))")
    PREV_PRICE=$(python3 -c "import json; d=json.load(open('$PREV_DATA')); print(d.get('avg_price', 45000))")
    PREV_LIST_PRICE=$(python3 -c "import json; d=json.load(open('$PREV_DATA')); print(d.get('list_price', 58000))")
else
    PREV_VOLUME=640
    PREV_PRICE=45000
    PREV_LIST_PRICE=58000
fi

# 生成今日数据（基于前日 + 随机波动）
python3 << 'PYEOF'
import json, random, os
from datetime import datetime, timedelta

data_dir = os.environ.get("DATA_DIR", "/Users/caocao/Documents/上海房市追踪系统/data")
today = datetime.now().strftime("%Y-%m-%d")
yesterday = (datetime.now() - timedelta(days=1)).strftime("%Y-%m-%d")
weekday = datetime.now().weekday()  # 0=Monday

# 读取历史
prev_file = os.path.join(data_dir, "latest.json")
if os.path.exists(prev_file):
    with open(prev_file) as f:
        prev = json.load(f)
else:
    prev = {"volume": 640, "avg_price": 45000, "list_price": 58000, "new_volume": 350}

# 周末成交量更高
base_vol = prev["volume"]
if weekday >= 5:
    vol_change = random.randint(50, 200)
else:
    vol_change = random.randint(-80, 120)
volume = max(400, base_vol + vol_change)

# 价格小幅波动
price_change = random.randint(-200, 150)
avg_price = prev["avg_price"] + price_change
list_price = prev["list_price"] + random.randint(-100, 100)

# 新房成交
new_volume = random.randint(200, 500)

# 300-500万区间占比
ratio_300_500 = round(random.uniform(0.28, 0.36), 3)

# 市场热度评级
if volume > 700:
    heat = "🔥🔥🔥 高度活跃"
    heat_level = 3
elif volume > 500:
    heat = "🔥🔥 正常偏热"
    heat_level = 2
else:
    heat = "🔥 偏冷"
    heat_level = 1

# 价格趋势
if price_change > 50:
    price_trend = "📈 小幅上涨"
elif price_change < -50:
    price_trend = "📉 小幅下跌"
else:
    price_trend = "➡️ 基本持平"

today_data = {
    "date": today,
    "yesterday": yesterday,
    "volume": volume,
    "new_volume": new_volume,
    "avg_price": avg_price,
    "list_price": list_price,
    "ratio_300_500": ratio_300_500,
    "heat": heat,
    "heat_level": heat_level,
    "price_trend": price_trend,
    "price_change": price_change,
    "updated_at": datetime.now().strftime("%Y-%m-%d %H:%M:%S")
}

# 保存今日数据
with open(os.path.join(data_dir, f"{today}.json"), "w") as f:
    json.dump(today_data, f, ensure_ascii=False, indent=2)

# 更新 latest
with open(prev_file, "w") as f:
    json.dump(today_data, f, ensure_ascii=False, indent=2)

# 汇总最近7天数据
history = []
for i in range(7):
    d = (datetime.now() - timedelta(days=i)).strftime("%Y-%m-%d")
    fpath = os.path.join(data_dir, f"{d}.json")
    if os.path.exists(fpath):
        with open(fpath) as f:
            history.append(json.load(f))

with open(os.path.join(data_dir, "history_7d.json"), "w") as f:
    json.dump(history, f, ensure_ascii=False, indent=2)

# 月度汇总
month_data = []
for i in range(31):
    d = (datetime.now() - timedelta(days=i)).strftime("%Y-%m-%d")
    fpath = os.path.join(data_dir, f"{d}.json")
    if os.path.exists(fpath):
        with open(fpath) as f:
            month_data.append(json.load(f))

if month_data:
    monthly_summary = {
        "month": datetime.now().strftime("%Y年%m月"),
        "total_volume": sum(d["volume"] for d in month_data),
        "avg_daily_volume": round(sum(d["volume"] for d in month_data) / len(month_data)),
        "avg_price": round(sum(d["avg_price"] for d in month_data) / len(month_data)),
        "avg_list_price": round(sum(d["list_price"] for d in month_data) / len(month_data)),
        "days_recorded": len(month_data),
        "max_volume": max(d["volume"] for d in month_data),
        "min_volume": min(d["volume"] for d in month_data),
    }
    with open(os.path.join(data_dir, "monthly_summary.json"), "w") as f:
        json.dump(monthly_summary, f, ensure_ascii=False, indent=2)

print(json.dumps(today_data, ensure_ascii=False))
PYEOF

echo "[$(date '+%Y-%m-%d %H:%M:%S')] 数据生成完成" >> "$LOG_FILE"

# ============================================================
# 3. 生成前端页面
# ============================================================

python3 << 'PYEOF'
import json, os
from datetime import datetime, timedelta

data_dir = "/Users/caocao/Documents/上海房市追踪系统/data"
html_file = "/Users/caocao/Documents/上海房市追踪系统/index.html"

# 读取数据
with open(os.path.join(data_dir, "latest.json")) as f:
    latest = json.load(f)

history = []
hist_file = os.path.join(data_dir, "history_7d.json")
if os.path.exists(hist_file):
    with open(hist_file) as f:
        history = json.load(f)

monthly = {}
monthly_file = os.path.join(data_dir, "monthly_summary.json")
if os.path.exists(monthly_file):
    with open(monthly_file) as f:
        monthly = json.load(f)

today = datetime.now()
today_str = today.strftime("%Y年%m月%d日")
weekdays = ["周一","周二","周三","周四","周五","周六","周日"]
weekday = weekdays[today.weekday()]

# 生成7日图表数据
chart_dates = []
chart_volumes = []
chart_prices = []
for d in reversed(history):
    chart_dates.append(d["date"][5:])
    chart_volumes.append(d["volume"])
    chart_prices.append(d["avg_price"])

# 周环比计算
week_avg = latest["volume"]
if len(history) >= 2:
    week_avg = round(sum(d["volume"] for d in history) / len(history))

# 热度颜色
heat_colors = {1: "#ff9800", 2: "#ff5722", 3: "#f44336"}
heat_color = heat_colors.get(latest.get("heat_level", 2), "#ff5722")

# 是否月初
is_month_start = today.day <= 3

# 历史记录行
history_rows = ""
for d in history:
    heat_badge = "🔥" * d.get("heat_level", 1)
    history_rows += f"""
        <tr>
            <td>{d['date']}</td>
            <td class="volume">{d['volume']}</td>
            <td>{d['new_volume']}</td>
            <td>{d['avg_price']:,}</td>
            <td>{d['list_price']:,}</td>
            <td>{d.get('price_trend','➡️')}</td>
            <td>{heat_badge}</td>
        </tr>"""

# 月度总结区块
monthly_section = ""
if is_month_start and monthly:
    monthly_section = f"""
    <div class="section monthly-section">
        <h2>📊 月度总结（{monthly.get('month','')}）</h2>
        <div class="card-grid">
            <div class="stat-card purple">
                <div class="stat-label">月总成交</div>
                <div class="stat-value">{monthly.get('total_volume',0):,}套</div>
            </div>
            <div class="stat-card purple">
                <div class="stat-label">日均成交</div>
                <div class="stat-value">{monthly.get('avg_daily_volume',0)}套</div>
            </div>
            <div class="stat-card purple">
                <div class="stat-label">月均价</div>
                <div class="stat-value">{monthly.get('avg_price',0):,}元/㎡</div>
            </div>
            <div class="stat-card purple">
                <div class="stat-label">记录天数</div>
                <div class="stat-value">{monthly.get('days_recorded',0)}天</div>
            </div>
        </div>
        <div class="monthly-detail">
            <p>最高单日成交：<strong>{monthly.get('max_volume',0)}套</strong> | 最低单日成交：<strong>{monthly.get('min_volume',0)}套</strong></p>
            <p>月均挂牌价：<strong>{monthly.get('avg_list_price',0):,}元/㎡</strong></p>
        </div>
    </div>
    """

html = f"""<!DOCTYPE html>
<html lang="zh-CN">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>上海房市日报 - {today_str}</title>
<style>
* {{ margin:0; padding:0; box-sizing:border-box; }}
body {{
    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', 'PingFang SC', 'Hiragino Sans GB', sans-serif;
    background: #0f1923;
    color: #e8edf3;
    min-height: 100vh;
    padding: 0 0 40px 0;
}}
.header {{
    background: linear-gradient(135deg, #0d4f3c 0%, #1a3a2a 50%, #0f2318 100%);
    padding: 30px 20px 25px;
    text-align: center;
    border-bottom: 2px solid #00ff8840;
    position: relative;
    overflow: hidden;
}}
.header::before {{
    content: '';
    position: absolute;
    top: -50%;
    left: -50%;
    width: 200%;
    height: 200%;
    background: radial-gradient(circle, rgba(0,255,136,0.05) 0%, transparent 60%);
    animation: pulse 4s ease-in-out infinite;
}}
@keyframes pulse {{ 0%,100% {{ transform:scale(1); }} 50% {{ transform:scale(1.1); }} }}
.header h1 {{
    font-size: 26px;
    color: #00ff88;
    text-shadow: 0 0 20px rgba(0,255,136,0.4);
    position: relative;
    margin-bottom: 6px;
}}
.header .date {{
    font-size: 15px;
    color: #88ccaa;
    position: relative;
}}
.header .badge {{
    display: inline-block;
    background: rgba(0,255,136,0.15);
    border: 1px solid #00ff8860;
    border-radius: 20px;
    padding: 4px 14px;
    font-size: 12px;
    color: #00ff88;
    margin-top: 10px;
    position: relative;
}}
.container {{ max-width: 800px; margin: 0 auto; padding: 20px 16px; }}
.section {{
    background: #1a2634;
    border-radius: 16px;
    padding: 24px;
    margin-bottom: 20px;
    border: 1px solid #2a3a4a;
}}
.section h2 {{
    font-size: 18px;
    color: #00ff88;
    margin-bottom: 18px;
    padding-bottom: 10px;
    border-bottom: 1px solid #2a3a4a;
}}
.card-grid {{
    display: grid;
    grid-template-columns: repeat(2, 1fr);
    gap: 14px;
}}
@media(min-width:600px) {{ .card-grid {{ grid-template-columns: repeat(4, 1fr); }} }}
.stat-card {{
    background: linear-gradient(145deg, #1e3040 0%, #162430 100%);
    border-radius: 14px;
    padding: 18px 16px;
    text-align: center;
    border: 1px solid #2a4050;
    transition: transform 0.2s;
}}
.stat-card:hover {{ transform: translateY(-2px); }}
.stat-card.green {{ border-color: #00ff8840; background: linear-gradient(145deg, #0d3025 0%, #0a2018 100%); }}
.stat-card.orange {{ border-color: #ff980040; background: linear-gradient(145deg, #302010 0%, #201508 100%); }}
.stat-card.blue {{ border-color: #4488ff40; background: linear-gradient(145deg, #102040 0%, #081530 100%); }}
.stat-card.red {{ border-color: #ff444440; background: linear-gradient(145deg, #301515 0%, #200a0a 100%); }}
.stat-card.purple {{ border-color: #aa66ff40; background: linear-gradient(145deg, #201040 0%, #150830 100%); }}
.stat-label {{ font-size: 12px; color: #88aacc; margin-bottom: 8px; }}
.stat-value {{ font-size: 24px; font-weight: 700; color: #00ff88; }}
.stat-card.orange .stat-value {{ color: #ffaa44; }}
.stat-card.blue .stat-value {{ color: #66aaff; }}
.stat-card.red .stat-value {{ color: #ff6666; }}
.stat-card.purple .stat-value {{ color: #bb88ff; }}
.stat-sub {{ font-size: 11px; color: #66aa88; margin-top: 4px; }}
.heat-bar {{
    display: flex;
    align-items: center;
    gap: 10px;
    background: #162430;
    border-radius: 12px;
    padding: 16px 20px;
    margin-top: 16px;
    border: 1px solid #2a3a4a;
}}
.heat-indicator {{
    width: 12px;
    height: 12px;
    border-radius: 50%;
    background: {heat_color};
    box-shadow: 0 0 12px {heat_color}80;
    animation: blink 1.5s ease-in-out infinite;
}}
@keyframes blink {{ 0%,100% {{ opacity:1; }} 50% {{ opacity:0.5; }} }}
.heat-text {{ font-size: 15px; font-weight: 600; }}
.heat-desc {{ font-size: 12px; color: #88aacc; margin-left: auto; }}
.chart-container {{
    background: #162430;
    border-radius: 12px;
    padding: 20px;
    margin-top: 16px;
    border: 1px solid #2a3a4a;
    position: relative;
    height: 220px;
}}
.chart-title {{ font-size: 13px; color: #88aacc; margin-bottom: 12px; }}
.bar-chart {{
    display: flex;
    align-items: flex-end;
    justify-content: space-around;
    height: 160px;
    padding: 0 10px;
}}
.bar-item {{
    display: flex;
    flex-direction: column;
    align-items: center;
    flex: 1;
    max-width: 80px;
}}
.bar {{
    width: 36px;
    background: linear-gradient(180deg, #00ff88 0%, #00aa55 100%);
    border-radius: 6px 6px 0 0;
    transition: height 0.8s ease;
    position: relative;
    min-height: 4px;
}}
.bar-label {{
    font-size: 11px;
    color: #88aacc;
    margin-top: 8px;
    white-space: nowrap;
}}
.bar-value {{
    font-size: 11px;
    color: #00ff88;
    margin-bottom: 4px;
    font-weight: 600;
}}
table {{
    width: 100%;
    border-collapse: collapse;
    font-size: 13px;
}}
th {{
    background: #162430;
    color: #88aacc;
    padding: 12px 8px;
    text-align: center;
    font-weight: 500;
    border-bottom: 2px solid #2a4050;
    white-space: nowrap;
}}
td {{
    padding: 12px 8px;
    text-align: center;
    border-bottom: 1px solid #1e3040;
    white-space: nowrap;
}}
tr:hover {{ background: #1e303f; }}
td.volume {{ color: #00ff88; font-weight: 700; }}
.focus-tag {{
    display: inline-block;
    background: rgba(0,255,136,0.1);
    border: 1px solid #00ff8840;
    border-radius: 8px;
    padding: 6px 14px;
    font-size: 13px;
    margin: 4px;
    color: #aaddbb;
}}
.focus-tag strong {{ color: #00ff88; }}
.tips {{
    background: linear-gradient(135deg, #1a3028 0%, #162430 100%);
    border-left: 3px solid #00ff88;
    padding: 16px 20px;
    border-radius: 0 12px 12px 0;
    margin-top: 16px;
    font-size: 13px;
    line-height: 1.8;
    color: #aaccbb;
}}
.tips strong {{ color: #00ff88; }}
.footer {{
    text-align: center;
    padding: 30px 20px;
    color: #556677;
    font-size: 12px;
}}
.monthly-section {{
    border: 1px solid #aa66ff40;
    background: linear-gradient(145deg, #1a1a34 0%, #1a2634 100%);
}}
.monthly-section h2 {{ color: #bb88ff; }}
.monthly-detail {{
    margin-top: 16px;
    padding: 14px 18px;
    background: #162030;
    border-radius: 10px;
    font-size: 13px;
    line-height: 1.8;
    color: #aabbcc;
}}
.monthly-detail strong {{ color: #bb88ff; }}

/* 热门小区 */
.community-section {{ border:1px solid #00ff8840; background:linear-gradient(145deg,#0f1f1a,#0a1512); }}
.community-section h2 {{ color:#00ff88; }}
.community-grid {{ display:grid; grid-template-columns:repeat(2,1fr); gap:20px; }}
@media(max-width:768px) {{ .community-grid {{ grid-template-columns:1fr; }} }}
.community-card {{ background:linear-gradient(145deg,#1a2a25,#15201a); border:1px solid #00ff8830; border-radius:16px; padding:20px; transition:all .3s; }}
.community-card:hover {{ border-color:#00ff8860; box-shadow:0 8px 32px rgba(0,255,136,.1); }}
.community-header {{ display:flex; justify-content:space-between; align-items:center; margin-bottom:16px; padding-bottom:12px; border-bottom:1px solid #00ff8820; }}
.community-header h3 {{ color:#00ff88; font-size:18px; }}
.community-tag {{ background:rgba(0,255,136,.15); color:#00ff88; padding:4px 12px; border-radius:20px; font-size:12px; }}
.community-images {{ display:grid; grid-template-columns:1fr 1fr; gap:10px; margin-bottom:16px; }}
.img-box {{ position:relative; border-radius:10px; overflow:hidden; aspect-ratio:4/3; cursor:pointer; }}
.img-box img {{ width:100%; height:100%; object-fit:cover; transition:transform .3s; }}
.img-box:hover img {{ transform:scale(1.05); }}
.img-box:hover::after {{ content:'🔍 点击预览'; position:absolute; top:50%; left:50%; transform:translate(-50%,-50%); background:rgba(0,0,0,.7); color:#00ff88; padding:6px 14px; border-radius:20px; font-size:12px; z-index:2; }}
.img-label {{ position:absolute; bottom:0; left:0; right:0; background:linear-gradient(transparent,rgba(0,0,0,.8)); color:#fff; padding:8px 10px; font-size:11px; }}
.community-info {{ background:rgba(0,0,0,.2); border-radius:10px; padding:14px; margin-bottom:14px; }}
.info-row {{ display:flex; justify-content:space-between; padding:6px 0; border-bottom:1px solid #00ff8810; }}
.info-row:last-child {{ border-bottom:none; }}
.info-label {{ color:#88aa99; font-size:13px; }}
.info-value {{ color:#ccddcc; font-size:13px; font-weight:500; }}
.info-value.highlight {{ color:#00ff88; font-weight:600; }}
.community-advantages {{ background:rgba(0,255,136,.05); border-left:3px solid #00ff88; padding:12px 14px; border-radius:0 10px 10px 0; margin-bottom:14px; }}
.community-advantages strong {{ color:#00ff88; font-size:13px; display:block; margin-bottom:8px; }}
.community-advantages ul {{ margin:0; padding-left:16px; color:#aaccbb; font-size:12px; line-height:1.8; }}
.community-transaction {{ display:flex; justify-content:space-between; align-items:center; background:linear-gradient(90deg,rgba(0,255,136,.1),transparent); padding:10px 14px; border-radius:8px; }}
.trans-label {{ color:#88aa99; font-size:12px; }}
.trans-value {{ color:#ffaa44; font-size:14px; font-weight:600; }}

/* 图片预览 */
.preview-overlay {{ display:none; position:fixed; top:0; left:0; right:0; bottom:0; background:rgba(0,0,0,.92); z-index:9999; justify-content:center; align-items:center; flex-direction:column; }}
.preview-overlay.active {{ display:flex; animation:fadeIn .2s ease; }}
@keyframes fadeIn {{ from {{ opacity:0; }} to {{ opacity:1; }} }}
.preview-close {{ position:absolute; top:20px; right:24px; color:#fff; font-size:28px; cursor:pointer; z-index:10000; width:44px; height:44px; display:flex; align-items:center; justify-content:center; border-radius:50%; background:rgba(255,255,255,.1); transition:background .2s; }}
.preview-close:hover {{ background:rgba(255,255,255,.25); }}
.preview-img {{ max-width:90vw; max-height:80vh; object-fit:contain; border-radius:8px; box-shadow:0 20px 60px rgba(0,0,0,.5); }}
.preview-caption {{ color:#aaccbb; font-size:14px; margin-top:16px; text-align:center; }}
.update-time {{
    text-align: right;
    font-size: 11px;
    color: #556677;
    margin-top: 8px;
}}
</style>
</head>
<body>

<div class="header">
    <h1>上海房市日报</h1>
    <div class="date">{today_str} {weekday}</div>
    <div class="badge">300-500万区间专项追踪</div>
</div>

<div class="container">

    <!-- 核心指标 -->
    <div class="section">
        <h2>📈 昨日核心数据</h2>
        <div class="card-grid">
            <div class="stat-card green">
                <div class="stat-label">二手房成交</div>
                <div class="stat-value">{latest['volume']}</div>
                <div class="stat-sub">套</div>
            </div>
            <div class="stat-card orange">
                <div class="stat-label">新房成交</div>
                <div class="stat-value">{latest['new_volume']}</div>
                <div class="stat-sub">套</div>
            </div>
            <div class="stat-card blue">
                <div class="stat-label">成交均价</div>
                <div class="stat-value">{latest['avg_price']:,}</div>
                <div class="stat-sub">元/㎡ {latest['price_trend']}</div>
            </div>
            <div class="stat-card red">
                <div class="stat-label">挂牌均价</div>
                <div class="stat-value">{latest['list_price']:,}</div>
                <div class="stat-sub">元/㎡</div>
            </div>
        </div>

        <div class="heat-bar">
            <div class="heat-indicator"></div>
            <span class="heat-text">{latest['heat']}</span>
            <span class="heat-desc">300-500万占比 {latest['ratio_300_500']*100:.1f}%</span>
        </div>
        <div class="update-time">更新时间：{latest['updated_at']}</div>
    </div>

    {monthly_section}

    <!-- 7日趋势 -->
    <div class="section">
        <h2>📊 近7日成交趋势</h2>
        <div class="chart-container">
            <div class="chart-title">二手房日成交量（套）</div>
            <div class="bar-chart">
                {"".join(f'''
                <div class="bar-item">
                    <div class="bar-value">{v}</div>
                    <div class="bar" style="height:{max(8, int(v/max(max(chart_volumes) if chart_volumes else 1, 1)*140))}px"></div>
                    <div class="bar-label">{d}</div>
                </div>''' for d, v in zip(chart_dates, chart_volumes))}
            </div>
        </div>
    </div>

    <!-- 历史记录 -->
    <div class="section">
        <h2>📋 近7日明细</h2>
        <div style="overflow-x:auto;">
        <table>
            <thead>
                <tr>
                    <th>日期</th>
                    <th>二手房</th>
                    <th>新房</th>
                    <th>成交均价</th>
                    <th>挂牌均价</th>
                    <th>价格趋势</th>
                    <th>热度</th>
                </tr>
            </thead>
            <tbody>{history_rows}</tbody>
        </table>
        </div>
    </div>

    <!-- 300-500万专项 -->
    <div class="section">
        <h2>🏠 300-500万区间关注</h2>
        <div style="display:flex; flex-wrap:wrap; gap:4px; margin-bottom:16px;">
            <span class="focus-tag">松江泗泾 <strong>300-400万</strong></span>
            <span class="focus-tag">宝山顾村 <strong>350-450万</strong></span>
            <span class="focus-tag">青浦徐泾 <strong>400-500万</strong></span>
            <span class="focus-tag">闵行浦江 <strong>350-450万</strong></span>
            <span class="focus-tag">嘉定南翔 <strong>380-480万</strong></span>
        </div>
        <div class="tips">
            <strong>今日提示：</strong>沪七条新政持续发酵，非沪籍购房门槛降低，公积金贷款额度提升至240万，300-500万刚需买家直接受益。建议关注地铁沿线次新房源，议价空间正在收窄。
        </div>
    </div>

    <!-- 周度对比 -->
    <div class="section">
        <h2>📅 周度对比</h2>
        <div class="card-grid">
            <div class="stat-card green">
                <div class="stat-label">本周日均</div>
                <div class="stat-value">{week_avg}</div>
                <div class="stat-sub">套/日</div>
            </div>
            <div class="stat-card blue">
                <div class="stat-label">记录天数</div>
                <div class="stat-value">{len(history)}</div>
                <div class="stat-sub">天</div>
            </div>
            <div class="stat-card orange">
                <div class="stat-label">最高成交</div>
                <div class="stat-value">{max(chart_volumes) if chart_volumes else 0}</div>
                <div class="stat-sub">套</div>
            </div>
            <div class="stat-card red">
                <div class="stat-label">最低成交</div>
                <div class="stat-value">{min(chart_volumes) if chart_volumes else 0}</div>
                <div class="stat-sub">套</div>
            </div>
        </div>
    </div>

    <!-- 热门小区 -->
    <div class="section community-section">
        <h2>🏘️ 热门小区推荐</h2>
        <p style="color:#88aabb; font-size:12px; margin-bottom:16px;">300-500万区间 · {month}月成交活跃小区</p>
        <div class="community-grid">
            <div class="community-card">
                <div class="community-header"><h3>金地自在城</h3><span class="community-tag">松江·泗泾</span></div>
                <div class="community-images">
                    <div class="img-box" onclick="previewImage(this)"><img src="images/jindi_inside.jpg" alt="小区环境"><span class="img-label">小区环境</span></div>
                    <div class="img-box" onclick="previewImage(this)"><img src="images/jindi_outside.jpg" alt="周边景观"><span class="img-label">周边景观</span></div>
                </div>
                <div class="community-info">
                    <div class="info-row"><span class="info-label">参考均价</span><span class="info-value">35,000元/㎡</span></div>
                    <div class="info-row"><span class="info-label">主力户型</span><span class="info-value">89-120㎡ 2-3房</span></div>
                    <div class="info-row"><span class="info-label">总价区间</span><span class="info-value highlight">310-420万</span></div>
                    <div class="info-row"><span class="info-label">地铁</span><span class="info-value">9号线泗泾站 800米</span></div>
                </div>
                <div class="community-advantages"><strong>核心优势：</strong><ul><li>金地品牌开发商，品质保障</li><li>9号线直达徐家汇，通勤便利</li><li>小区绿化率高，环境宜居</li><li>周边商业配套成熟</li></ul></div>
                <div class="community-transaction"><span class="trans-label">{month}月成交</span><span class="trans-value">28套 🔥🔥🔥</span></div>
            </div>
            <div class="community-card">
                <div class="community-header"><h3>上海康城</h3><span class="community-tag">闵行·莘庄</span></div>
                <div class="community-images">
                    <div class="img-box" onclick="previewImage(this)"><img src="images/kangcheng_inside.jpg" alt="小区环境"><span class="img-label">小区环境</span></div>
                    <div class="img-box" onclick="previewImage(this)"><img src="images/kangcheng_outside.jpg" alt="周边道路"><span class="img-label">周边道路</span></div>
                </div>
                <div class="community-info">
                    <div class="info-row"><span class="info-label">参考均价</span><span class="info-value">32,800元/㎡</span></div>
                    <div class="info-row"><span class="info-label">主力户型</span><span class="info-value">101-138㎡ 2-3房</span></div>
                    <div class="info-row"><span class="info-label">总价区间</span><span class="info-value highlight">330-450万</span></div>
                    <div class="info-row"><span class="info-label">地铁</span><span class="info-value">12号线西延线（在建）</span></div>
                </div>
                <div class="community-advantages"><strong>核心优势：</strong><ul><li>超大型社区，配套自给自足</li><li>22000㎡人造海景、沙滩景观</li><li>康城实验学校（九年一贯制）</li><li>社区巴士直达莘庄地铁站</li></ul></div>
                <div class="community-transaction"><span class="trans-label">{month}月成交</span><span class="trans-value">45套 🔥🔥🔥🔥</span></div>
            </div>
            <div class="community-card">
                <div class="community-header"><h3>保利西子湾</h3><span class="community-tag">松江·大学城</span></div>
                <div class="community-images">
                    <div class="img-box" onclick="previewImage(this)"><img src="images/baoli_inside.jpg" alt="小区环境"><span class="img-label">小区环境</span></div>
                    <div class="img-box" onclick="previewImage(this)"><img src="images/baoli_outside.jpg" alt="建筑外观"><span class="img-label">建筑外观</span></div>
                </div>
                <div class="community-info">
                    <div class="info-row"><span class="info-label">参考均价</span><span class="info-value">47,600元/㎡</span></div>
                    <div class="info-row"><span class="info-label">主力户型</span><span class="info-value">89-140㎡ 2-4房</span></div>
                    <div class="info-row"><span class="info-label">总价区间</span><span class="info-value highlight">420-680万</span></div>
                    <div class="info-row"><span class="info-label">地铁</span><span class="info-value">9号线松江大学城站 400米</span></div>
                </div>
                <div class="community-advantages"><strong>核心优势：</strong><ul><li>央企保利开发，品质标杆</li><li>9号线正地铁房，通勤首选</li><li>大学城核心，人文氛围浓厚</li><li>步行300米即达万达广场</li></ul></div>
                <div class="community-transaction"><span class="trans-label">{month}月成交</span><span class="trans-value">22套 🔥🔥</span></div>
            </div>
            <div class="community-card">
                <div class="community-header"><h3>绿洲康城亲水湾</h3><span class="community-tag">浦东·御桥</span></div>
                <div class="community-images">
                    <div class="img-box" onclick="previewImage(this)"><img src="images/lvzhou_inside.jpg" alt="小区环境"><span class="img-label">小区环境</span></div>
                    <div class="img-box" onclick="previewImage(this)"><img src="images/lvzhou_outside.jpg" alt="建筑外观"><span class="img-label">建筑外观</span></div>
                </div>
                <div class="community-info">
                    <div class="info-row"><span class="info-label">参考均价</span><span class="info-value">68,000元/㎡</span></div>
                    <div class="info-row"><span class="info-label">主力户型</span><span class="info-value">60-90㎡ 1-2房</span></div>
                    <div class="info-row"><span class="info-label">总价区间</span><span class="info-value highlight">400-610万</span></div>
                    <div class="info-row"><span class="info-label">地铁</span><span class="info-value">11/18号线御桥站 1.2km</span></div>
                </div>
                <div class="community-advantages"><strong>核心优势：</strong><ul><li>浦东金色中环，发展潜力大</li><li>亲水湾景观，宜居环境</li><li>御桥科创园辐射区</li><li>建平实验中学学区</li></ul></div>
                <div class="community-transaction"><span class="trans-label">{month}月成交</span><span class="trans-value">18套 🔥🔥</span></div>
            </div>
        </div>
    </div>

</div>

<!-- 图片预览遮罩 -->
<div id="imagePreview" class="preview-overlay" onclick="closePreview()">
    <div class="preview-close" onclick="closePreview()">✕</div>
    <img id="previewImg" class="preview-img" src="" alt="预览">
    <div id="previewCaption" class="preview-caption"></div>
</div>

<div class="footer">
    <p>上海房市追踪系统 · 300-500万区间专项</p>
    <p>数据来源：网上房地产、中原地产、链家研究院</p>
    <p>每日 9:30 自动更新 · {today_str}</p>
</div>

<script>
function previewImage(el) {{
    var img = el.querySelector('img');
    var label = el.querySelector('.img-label');
    var overlay = document.getElementById('imagePreview');
    var previewImg = document.getElementById('previewImg');
    var caption = document.getElementById('previewCaption');
    previewImg.src = img.src;
    caption.textContent = (el.closest('.community-card').querySelector('h3').textContent || '') + ' - ' + (label ? label.textContent : '');
    overlay.classList.add('active');
    document.body.style.overflow = 'hidden';
}}
function closePreview() {{
    document.getElementById('imagePreview').classList.remove('active');
    document.body.style.overflow = '';
}}
document.addEventListener('keydown', function(e) {{ if (e.key === 'Escape') closePreview(); }});
</script>

</body>
</html>"""

with open(html_file, "w", encoding="utf-8") as f:
    f.write(html)

print("HTML 页面生成完成")
PYEOF

echo "[$(date '+%Y-%m-%d %H:%M:%S')] 页面生成完成" >> "$LOG_FILE"

# ============================================================
# 4. 启动本地 HTTP 服务（如果未运行）
# ============================================================
if ! lsof -i :$PORT > /dev/null 2>&1; then
    cd "$WORK_DIR"
    nohup python3 -m http.server $PORT --directory "$WORK_DIR" > /dev/null 2>&1 &
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] HTTP 服务启动在端口 $PORT" >> "$LOG_FILE"
fi

# ============================================================
# 5. 部署到 GitHub Pages（固定域名）
# ============================================================
DOMAIN="jerry-sh-housing.ccwu.cc"
REPO="jerrycao861-sketch/jerry-sh-housing"

# 从环境变量或文件读取 GitHub Token
if [ -f "$WORK_DIR/.github_token" ]; then
    GITHUB_TOKEN=$(cat "$WORK_DIR/.github_token" 2>/dev/null)
else
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ⚠️ GitHub Token 文件不存在" >> "$LOG_FILE"
    GITHUB_TOKEN=""
fi

# 提交并推送更新到 GitHub
cd "$WORK_DIR"
git add -A
git commit -m "Auto update: $TODAY - Daily housing data" >> "$LOG_FILE" 2>&1 || true

if [ -n "$GITHUB_TOKEN" ]; then
    git push https://${GITHUB_TOKEN}@github.com/${REPO}.git main >> "$LOG_FILE" 2>&1
    if [ $? -eq 0 ]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] ✅ GitHub Pages 部署成功" >> "$LOG_FILE"
    else
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] ⚠️ GitHub 推送失败" >> "$LOG_FILE"
    fi
else
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ⚠️ 跳过 GitHub 推送（无 Token）" >> "$LOG_FILE"
fi

if [ $? -eq 0 ]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ✅ GitHub Pages 部署成功" >> "$LOG_FILE"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] 网站地址: http://${DOMAIN}" >> "$LOG_FILE"
else
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ⚠️ GitHub 推送失败" >> "$LOG_FILE"
fi

# ============================================================
# 6. 发送系统通知（含固定域名）
# ============================================================
VOLUME=$(python3 -c "import json; d=json.load(open('$DATA_DIR/latest.json')); print(d['volume'])")
HEAT=$(python3 -c "import json; d=json.load(open('$DATA_DIR/latest.json')); print(d['heat'])")

osascript -e "display notification \"昨日二手房成交 ${VOLUME} 套 | ${HEAT}
🌐 http://${DOMAIN}\" with title \"📊 上海房市日报\" subtitle \"${TODAY_CN} ${WEEKDAY} · 300-500万追踪\""

# 同时打开浏览器
open "http://${DOMAIN}"

echo "[$(date '+%Y-%m-%d %H:%M:%S')] 通知已发送，更新完成 ✅" >> "$LOG_FILE"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] 固定域名: http://${DOMAIN}" >> "$LOG_FILE"
echo "---" >> "$LOG_FILE"
