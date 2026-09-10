import { Link } from "react-router-dom";
import { useApp } from "../context";

const items = [
  {
    e: "Road Transport & Heavy Fleet",
    a: "النقل البري والأسطول الثقيل",
    de: "GPS-tracked modern trucks, flatbeds for containers, and temperature-controlled reefers ensuring nationwide secure transit.",
    da: "شاحنات حديثة بتتبع GPS ومنصات حاويات وثلاجات مبردة لنقل آمن على مستوى البلاد.",
    points: [
      ["Real-time GPS fleet tracking", "تتبع الأسطول لحظياً"],
      ["Container flatbeds and specialized reefers", "منصات حاويات وثلاجات متخصصة"],
      ["Nationwide secure distribution network", "شبكة توزيع وطنية آمنة"],
    ],
  },
  {
    e: "Sea Freight",
    a: "الشحن البحري",
    de: "FCL and LCL capabilities, strategic partnerships with global ocean carriers, and robust port operations.",
    da: "حلول FCL و LCL وشراكات مع خطوط ملاحية عالمية وعمليات موانئ قوية.",
    points: [
      ["FCL & LCL maritime solutions", "حلول بحرية FCL و LCL"],
      ["Strategic global carrier partnerships", "شراكات خطوط عالمية"],
      ["Reliable ocean freight routing", "مسارات شحن بحري موثوقة"],
    ],
  },
  {
    e: "Customs Clearance",
    a: "التخليص الجمركي",
    de: "Robust operations at Alexandria Port featuring strict compliance management, rapid cargo release, and expert handling of import/export documentation.",
    da: "عمليات قوية في ميناء الإسكندرية مع امتثال صارم وإفراج سريع عن البضائع ومعالجة وثائق الاستيراد والتصدير.",
    points: [
      ["Accelerated Alexandria Port clearance", "تخليص سريع في ميناء الإسكندرية"],
      ["Standard import/export documentation", "وثائق استيراد وتصدير قياسية"],
      ["Comprehensive regulatory compliance", "امتثال تنظيمي شامل"],
    ],
  },
  {
    e: "Smart Warehousing",
    a: "التخزين الذكي",
    de: "Strategically located bonded and non-bonded facilities, advanced inventory tracking, and highly secure cargo staging areas.",
    da: "منشآت جمركية وغير جمركية بمواقع استراتيجية وتتبع مخزون متقدم ومناطق تجهيز آمنة.",
    points: [
      ["Bonded and non-bonded storage", "تخزين جمركي وغير جمركي"],
      ["Advanced inventory tracking systems", "أنظمة تتبع مخزون متقدمة"],
      ["Highly secure cargo staging operations", "تجهيز شحنات شديد الأمان"],
    ],
  },
  {
    e: "Project Cargo & Heavy Lift",
    a: "شحنات المشروعات والرفع الثقيل",
    de: "Specialized logistics for oversized industrial machinery, factory relocations, and complex engineering payloads requiring meticulous route planning.",
    da: "لوجستيات متخصصة للآلات الصناعية الضخمة ونقل المصانع والحمولات الهندسية المعقدة.",
    points: [
      ["Oversized industrial machinery transport", "نقل آلات صناعية كبيرة"],
      ["Turnkey factory relocations", "نقل مصانع متكامل"],
      ["Meticulous heavy-lift route planning", "تخطيط مسارات الرفع الثقيل"],
    ],
  },
];

export default function Logistics() {
  const { lang } = useApp();
  const en = lang === "en";
  return (
    <>
      <section className="page-hero">
        <h1>{en ? "Gosst Logistics & Freight" : "جوست للوجستيات والشحن"}</h1>
        <p>{en ? "End-to-end supply chain mastery, powered by our strategic Alexandria operations hub." : "إتقان سلسلة الإمداد من الطرف إلى الطرف عبر مركز عملياتنا في الإسكندرية."}</p>
      </section>
      <section className="section">
        <div className="grid" style={{ gap: 24 }}>
          {items.map((item) => (
            <article className="card" key={item.e}>
              <h3>{en ? item.e : item.a}</h3>
              <p>{en ? item.de : item.da}</p>
              <ul>
                {item.points.map(([e, a]) => (
                  <li key={e}>{en ? e : a}</li>
                ))}
              </ul>
            </article>
          ))}
        </div>
        <div className="btns" style={{ marginTop: 32 }}>
          <Link className="btn btn-red" to="/catalog">{en ? "Request a Logistics Quote" : "اطلب عرض سعر لوجستي"}</Link>
        </div>
      </section>
    </>
  );
}
