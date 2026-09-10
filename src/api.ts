import type { CustomerRequest, Product } from "./types";

const headers = (token?: string | null) => ({
  "Content-Type": "application/json",
  ...(token ? { Authorization: `Bearer ${token}` } : {}),
});

export async function fetchProducts(): Promise<Product[]> {
  const res = await fetch("/api/products");
  if (!res.ok) throw new Error("Failed to load products");
  return res.json();
}

export async function loginAdmin(password: string): Promise<string> {
  const res = await fetch("/api/login", {
    method: "POST",
    headers: headers(),
    body: JSON.stringify({ password }),
  });
  if (!res.ok) throw new Error("Invalid password");
  const data = await res.json();
  return data.token;
}

export async function saveProduct(token: string, product: Partial<Product> & { id?: string }) {
  const url = product.id ? `/api/products/${product.id}` : "/api/products";
  const res = await fetch(url, {
    method: product.id ? "PUT" : "POST",
    headers: headers(token),
    body: JSON.stringify(product),
  });
  if (!res.ok) throw new Error("Save failed");
  return res.json() as Promise<Product>;
}

export async function deleteProduct(token: string, id: string) {
  const res = await fetch(`/api/products/${id}`, { method: "DELETE", headers: headers(token) });
  if (!res.ok) throw new Error("Delete failed");
}

export async function submitRequest(payload: {
  company: string;
  name: string;
  phone: string;
  email: string;
  notes: string;
  items: unknown[];
}) {
  const res = await fetch("/api/requests", {
    method: "POST",
    headers: headers(),
    body: JSON.stringify(payload),
  });
  if (!res.ok) throw new Error("Request failed");
  return res.json();
}

export async function fetchRequests(token: string): Promise<CustomerRequest[]> {
  const res = await fetch("/api/requests", { headers: headers(token) });
  if (!res.ok) throw new Error("Failed to load requests");
  return res.json();
}

export async function updateRequestStatus(token: string, id: string, status: string) {
  const res = await fetch(`/api/requests/${id}`, {
    method: "PATCH",
    headers: headers(token),
    body: JSON.stringify({ status }),
  });
  if (!res.ok) throw new Error("Update failed");
  return res.json();
}
