import { Link } from "react-router-dom";
import { useApp } from "../context";

const groups = [
  {
    id: "vegetables",
    e: "Fresh Vegetables",
    a: "خضروات طازجة",
    de: "We maintain strict cold-chain integrity from farm to facility, ensuring our vegetables retain maximum freshness and nutritional value.",
    da: "نحافظ على سلسلة تبريد متصلة من المزرعة إلى المنشأة لضمان أقصى طزاجة.",
    points: [
      ["Unbroken cold-chain maintenance", "سلسلة تبريد غير منقطعة"],
      ["Direct agricultural partnerships", "شراكات زراعية مباشرة"],
      ["Rigorous international sorting standards", "معايير فرز دولية صارمة"],
    ],
  },
  {
    id: "fruits",
    e: "Fresh Fruits",
    a: "فواكه طازجة",
    de: "Our premium fruits are hand-selected for seasonal availability, ensuring high-yield quality for export and corporate hospitality.",
    da: "فواكه فاخرة منتقاة يدوياً حسب الموسم بجودة تصدير وضيافة مؤسسية.",
    points: [
      ["Year-round seasonal availability", "توافر موسمي على مدار العام"],
      ["Export-grade premium packaging", "تعبئة فاخرة بدرجة تصدير"],
      ["Rapid transit for ultimate freshness", "نقل سريع لأقصى طزاجة"],
    ],
  },
  {
    id: "hotel",
    e: "Hotel & Hospitality Supplies",
    a: "مستلزمات الفنادق والضيافة",
    de: "Comprehensive supply solutions designed specifically for the rigorous demands of the hospitality sector.",
    da: "حلول توريد شاملة لمتطلبات قطاع الضيافة.",
    points: [
      ["Luxury linens and textiles", "مفروشات ومنسوجات فاخرة"],
      ["Commercial-grade kitchenware", "أدوات مطبخ تجارية"],
      ["Premium guest amenities", "مستلزمات نزلاء فاخرة"],
    ],
  },
  {
    id: "office",
    e: "Office Stationery",
    a: "القرطاسية المكتبية",
    de: "Complete corporate office supplies that ensure your daily administrative operations run flawlessly.",
    da: "مستلزمات مكتبية كاملة لتشغيل إداري يومي سلس.",
    points: [
      ["Corporate printing solutions", "حلول طباعة للشركات"],
      ["Modern tech accessories", "إكسسوارات تقنية حديثة"],
      ["Bulk paper and daily supplies", "ورق ومستلزمات يومية بالجملة"],
    ],
  },
  {
    id: "packaging",
    e: "Packaging Materials",
    a: "مواد التعبئة",
    de: "Robust and secure packaging materials tailored for heavy-duty corporate transport and storage.",
    da: "مواد تعبئة قوية وآمنة للنقل والتخزين المؤسسي.",
    points: [
      ["Heavy-duty shipping cartons", "كراتين شحن قوية"],
      ["Protective bubble wrap and seals", "فقاعات حماية وأختام"],
      ["Custom corporate branding options", "خيارات علامة تجارية مخصصة"],
    ],
  },
];

export default function Supplies() {
  const { lang } = useApp();
  const en = lang === "en";
  return (
    <>
      <section className="page-hero">
        <h1>{en ? "Gosst Supplies Division" : "قسم التوريدات في جوست"}</h1>
        <p>{en ? "Delivering premium quality and massive scale across global trade networks." : "جودة فاخرة وحجم كبير عبر شبكات التجارة العالمية."}</p>
      </section>
      <section className="section">
        <div className="grid" style={{ gap: 24 }}>
          {groups.map((g) => (
            <article className="card" key={g.id} id={g.id}>
              <h3>{en ? g.e : g.a}</h3>
              <p>{en ? g.de : g.da}</p>
              <ul>
                {g.points.map(([e, a]) => (
                  <li key={e}>{en ? e : a}</li>
                ))}
              </ul>
              <Link className="btn btn-navy" to={`/catalog?cat=${g.id}`}>{en ? "View quotes" : "عرض الأسعار"}</Link>
            </article>
          ))}
        </div>
      </section>
    </>
  );
}
