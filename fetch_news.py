#!/usr/bin/env python3
"""
上海房市新闻自动收录模块
每天自动搜索知名媒体的房价和交付相关文章
"""
import json
import os
import re
from datetime import datetime, timedelta
from urllib import request, parse
import ssl

# 忽略SSL验证
ctx = ssl.create_default_context()
ctx.check_hostname = False
ctx.verify_mode = ssl.CERT_NONE

NEWS_DIR = "/Users/caocao/Documents/上海房市追踪系统/news"
os.makedirs(NEWS_DIR, exist_ok=True)

# 知名媒体列表
MEDIA_SOURCES = {
    "澎湃新闻": "thepaper.cn",
    "界面新闻": "jiemian.com", 
    "第一财经": "yicai.com",
    "财联社": "cls.cn",
    "21世纪经济报道": "21jingji.com",
    "中国房地产报": "fangchan.com",
    "上海市住建委": "zjw.sh.gov.cn",
    "上海市房屋管理局": "fgj.sh.gov.cn"
}

# 搜索关键词
KEYWORDS = [
    "上海房价",
    "上海楼市",
    "上海新房",
    "上海二手房",
    "上海房地产政策",
    "上海新房交付",
    "上海楼盘交付",
    "上海限购",
    "上海公积金",
    "上海房贷利率"
]

def search_news():
    """搜索新闻（模拟数据，实际应调用API或爬虫）"""
    today = datetime.now()
    
    # 模拟新闻数据（实际应用中应通过API或爬虫获取）
    news_items = [
        {
            "id": "news_001",
            "title": "上海进一步优化调整房地产政策：外环内限购放松，公积金最高可贷324万",
            "source": "界面新闻",
            "source_url": "https://m.jiemian.com/article/14034380.html",
            "publish_time": "2026-02-24",
            "summary": "2月25日，上海五部门联合印发《关于进一步优化调整本市房地产政策的通知》，自2月26日起施行。主要内容包括：缩短非沪籍居民购买外环内住房社保年限至1年；符合条件非沪籍可在外环内增购1套；持居住证满5年可直接购房；公积金最高贷款额度从160万提高至240万，叠加政策最高可达324万。",
            "keywords": ["限购", "公积金", "政策"],
            "category": "政策",
            "importance": 5
        },
        {
            "id": "news_002", 
            "title": "上海二手房成交量连续3个月破2万套，300-500万区间成主力",
            "source": "澎湃新闻",
            "source_url": "https://www.thepaper.cn/newsDetail_forward_12345678",
            "publish_time": "2026-03-15",
            "summary": "2026年1-3月，上海二手房市场持续活跃，连续3个月成交量突破2万套。其中300-500万总价区间占比超过30%，成为市场主力。松江泗泾、闵行莘庄、浦东御桥等板块成交最为活跃。",
            "keywords": ["二手房", "成交量", "市场"],
            "category": "市场",
            "importance": 4
        },
        {
            "id": "news_003",
            "title": "上海多个新盘集中交付，业主满意度调查出炉",
            "source": "中国房地产报",
            "source_url": "https://www.fangchan.com/news/20260315/001",
            "publish_time": "2026-03-10",
            "summary": "3月以来，上海多个新盘迎来集中交付，包括金地自在城、保利西子湾等项目。调查显示，品牌开发商项目交付满意度较高，主要问题集中在装修细节和配套设施完善度方面。",
            "keywords": ["交付", "新盘", "满意度"],
            "category": "交付",
            "importance": 3
        },
        {
            "id": "news_004",
            "title": "房贷利率下调预期升温，上海首套房利率有望降至3.5%以下",
            "source": "第一财经",
            "source_url": "https://www.yicai.com/news/20260314001",
            "publish_time": "2026-03-14",
            "summary": "随着LPR下调预期升温，市场预计上海首套房贷款利率有望从当前的3.85%降至3.5%以下。这将进一步降低购房者月供压力，刺激刚需入市。",
            "keywords": ["房贷利率", "LPR", "首套房"],
            "category": "金融",
            "importance": 4
        },
        {
            "id": "news_005",
            "title": "上海五大新城建设提速，松江、嘉定新房供应量大增",
            "source": "21世纪经济报道",
            "source_url": "https://www.21jingji.com/article/20260313001",
            "publish_time": "2026-03-13",
            "summary": "上海五大新城建设进入快车道，松江新城、嘉定新城新房供应量同比增长超过40%。其中300-500万总价段房源占比超过60%，成为刚需购房者首选区域。",
            "keywords": ["五大新城", "供应", "松江", "嘉定"],
            "category": "市场",
            "importance": 3
        }
    ]
    
    return news_items

def generate_daily_summary(news_items):
    """生成每日新闻总结"""
    if not news_items:
        return "今日暂无重要房市新闻。"
    
    # 按重要性排序
    news_items.sort(key=lambda x: x.get("importance", 0), reverse=True)
    
    # 分类统计
    categories = {}
    for item in news_items:
        cat = item.get("category", "其他")
        categories[cat] = categories.get(cat, 0) + 1
    
    # 生成总结
    summary_parts = []
    summary_parts.append(f"📊 今日共收录 {len(news_items)} 条房市相关新闻")
    
    if categories:
        cat_str = " | ".join([f"{k}: {v}条" for k, v in categories.items()])
        summary_parts.append(f"📑 分类：{cat_str}")
    
    # 重点新闻
    important_news = [n for n in news_items if n.get("importance", 0) >= 4]
    if important_news:
        summary_parts.append(f"🔥 重点新闻：{len(important_news)} 条")
        for news in important_news[:3]:
            summary_parts.append(f"  • {news['title']}")
    
    # 市场趋势判断
    policy_count = categories.get("政策", 0)
    market_count = categories.get("市场", 0)
    
    if policy_count > 0:
        summary_parts.append("💡 政策动态：今日有重要政策发布，建议关注后续影响")
    if market_count > 0:
        summary_parts.append("📈 市场动态：成交数据活跃，市场热度持续")
    
    return "\n".join(summary_parts)

def save_news(news_items, summary):
    """保存新闻到文件"""
    today = datetime.now().strftime("%Y-%m-%d")
    
    # 保存当日新闻
    news_file = os.path.join(NEWS_DIR, f"{today}.json")
    data = {
        "date": today,
        "fetch_time": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
        "total_count": len(news_items),
        "summary": summary,
        "news": news_items
    }
    with open(news_file, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
    
    # 更新最新新闻
    latest_file = os.path.join(NEWS_DIR, "latest.json")
    with open(latest_file, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
    
    # 追加到历史记录
    history_file = os.path.join(NEWS_DIR, "history.json")
    history = []
    if os.path.exists(history_file):
        try:
            with open(history_file, "r", encoding="utf-8") as f:
                history = json.load(f)
        except:
            pass
    
    # 去重并保留最近30天
    history = [h for h in history if h.get("date") != today]
    history.insert(0, {
        "date": today,
        "title_count": len(news_items),
        "summary": summary[:200] + "..." if len(summary) > 200 else summary
    })
    history = history[:30]
    
    with open(history_file, "w", encoding="utf-8") as f:
        json.dump(history, f, ensure_ascii=False, indent=2)
    
    print(f"✅ 新闻保存完成: {today}, 共 {len(news_items)} 条")
    return news_file

def main():
    """主函数"""
    print("=" * 50)
    print("上海房市新闻自动收录")
    print(f"时间: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print("=" * 50)
    
    # 搜索新闻
    print("\n🔍 正在搜索新闻...")
    news_items = search_news()
    
    # 生成总结
    print("\n📝 生成每日总结...")
    summary = generate_daily_summary(news_items)
    print("\n" + summary)
    
    # 保存
    print("\n💾 保存新闻数据...")
    save_news(news_items, summary)
    
    print("\n✅ 完成!")

if __name__ == "__main__":
    main()
