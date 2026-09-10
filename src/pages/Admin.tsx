import { FormEvent, useEffect, useState } from "react";
import { deleteProduct, fetchRequests, loginAdmin, saveProduct, updateRequestStatus } from "../api";
import { useApp } from "../context";
import { CATEGORIES, type CustomerRequest, type Product } from "../types";

export default function Admin() {
  const { lang, token, setToken, products, reloadProducts } = useApp();
  const en = lang === "en";
  const [password, setPassword] = useState("");
  const [requests, setRequests] = useState<CustomerRequest[]>([]);
  const [editing, setEditing] = useState<Partial<Product>>({ category: "vegetables", unit: "kg", price: 0 });
  const [err, setErr] = useState("");

  async function loadRequests(current = token) {
    if (!current) return;
    setRequests(await fetchRequests(current));
  }

  useEffect(() => {
    loadRequests().catch(() => setToken(null));
  }, [token]);

  async function onLogin(e: FormEvent) {
    e.preventDefault();
    setErr("");
    try {
      const t = await loginAdmin(password);
      setToken(t);
      await reloadProducts();
      await loadRequests(t);
    } catch {
      setErr(en ? "Wrong password" : "كلمة المرور غير صحيحة");
    }
  }

  async function onSave(e: FormEvent) {
    e.preventDefault();
    if (!token) return;
    await saveProduct(token, editing);
    setEditing({ category: "vegetables", unit: "kg", price: 0 });
    await reloadProducts();
  }

  if (!token) {
    return (
      <section className="section admin-login">
        <div className="card">
          <h2>{en ? "Gosst Admin" : "إدارة جوست"}</h2>
          <p className="muted">{en ? "Manage price quotes and incoming customer requests." : "إدارة عروض الأسعار وطلبات العملاء."}</p>
          <form className="form" onSubmit={onLogin}>
            <input type="password" value={password} onChange={(e) => setPassword(e.target.value)} placeholder={en ? "Admin password" : "كلمة مرور الأدمن"} />
            <button className="btn btn-navy">{en ? "Sign in" : "دخول"}</button>
            {err && <p className="muted">{err}</p>}
          </form>
        </div>
      </section>
    );
  }

  return (
    <section className="section">
      <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center" }}>
        <h2>{en ? "Admin dashboard" : "لوحة الإدارة"}</h2>
        <button className="btn btn-ghost" onClick={() => setToken(null)}>{en ? "Sign out" : "خروج"}</button>
      </div>

      <h3>{en ? "Incoming requests" : "طلبات العملاء"}</h3>
      {requests.length === 0 && <p className="muted">{en ? "No requests yet." : "لا توجد طلبات بعد."}</p>}
      {requests.map((r) => (
        <article className="card" key={r.id} style={{ marginBottom: 12 }}>
          <div style={{ display: "flex", justifyContent: "space-between", gap: 12, flexWrap: "wrap" }}>
            <div>
              <b>{r.name}</b> · {r.company || (en ? "No company" : "بدون شركة")}
              <div className="muted">{r.phone} {r.email && `· ${r.email}`}</div>
              <div className="muted">{new Date(r.createdAt).toLocaleString()}</div>
            </div>
            <div>
              <span className={`status ${r.status}`}>{r.status}</span>
              <select value={r.status} onChange={(e) => token && updateRequestStatus(token, r.id, e.target.value).then(() => loadRequests())}>
                <option value="new">{en ? "New" : "جديد"}</option>
                <option value="seen">{en ? "Seen" : "تمت المشاهدة"}</option>
                <option value="done">{en ? "Done" : "مكتمل"}</option>
              </select>
            </div>
          </div>
          <ul>
            {r.items.map((i) => (
              <li key={i.productId}>
                {en ? i.nameEn : i.nameAr} × {i.qty} {i.unit} — EGP {(i.price * i.qty).toFixed(2)}
              </li>
            ))}
          </ul>
          {r.notes && <p>{r.notes}</p>}
        </article>
      ))}

      <h3>{en ? "Price quotes" : "عروض الأسعار"}</h3>
      <form className="form card" onSubmit={onSave} style={{ marginBottom: 20 }}>
        <b>{editing.id ? (en ? "Edit quote" : "تعديل عرض") : (en ? "Add quote" : "إضافة عرض")}</b>
        <input value={editing.nameEn || ""} onChange={(e) => setEditing({ ...editing, nameEn: e.target.value })} placeholder="Name EN" required />
        <input value={editing.nameAr || ""} onChange={(e) => setEditing({ ...editing, nameAr: e.target.value })} placeholder="الاسم بالعربي" required />
        <textarea value={editing.descEn || ""} onChange={(e) => setEditing({ ...editing, descEn: e.target.value })} placeholder="Description EN" />
        <textarea value={editing.descAr || ""} onChange={(e) => setEditing({ ...editing, descAr: e.target.value })} placeholder="الوصف بالعربي" />
        <select value={editing.category} onChange={(e) => setEditing({ ...editing, category: e.target.value })}>
          {CATEGORIES.map((c) => (
            <option key={c.id} value={c.id}>{c.en}</option>
          ))}
        </select>
        <input value={editing.unit || ""} onChange={(e) => setEditing({ ...editing, unit: e.target.value })} placeholder={en ? "Unit" : "الوحدة"} />
        <input type="number" step="0.01" value={editing.price ?? 0} onChange={(e) => setEditing({ ...editing, price: Number(e.target.value) })} />
        <button className="btn btn-blue">{en ? "Save quote" : "حفظ العرض"}</button>
      </form>

      <table className="table">
        <thead>
          <tr>
            <th>{en ? "Product" : "المنتج"}</th>
            <th>{en ? "Category" : "القسم"}</th>
            <th>{en ? "Price" : "السعر"}</th>
            <th></th>
          </tr>
        </thead>
        <tbody>
          {products.map((p) => (
            <tr key={p.id}>
              <td>{en ? p.nameEn : p.nameAr}</td>
              <td>{p.category}</td>
              <td>EGP {p.price.toFixed(2)} / {p.unit}</td>
              <td>
                <button className="btn btn-ghost" onClick={() => setEditing(p)}>{en ? "Edit" : "تعديل"}</button>
                <button
                  className="btn btn-ghost"
                  onClick={async () => {
                    if (!token) return;
                    await deleteProduct(token, p.id);
                    await reloadProducts();
                  }}
                >
                  {en ? "Delete" : "حذف"}
                </button>
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </section>
  );
}
