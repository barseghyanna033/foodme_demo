import { expect, type APIRequestContext, type Page } from "@playwright/test";

export async function createAccountAtCheckout(
  page: Page,
  name = "Casey Delivery",
) {
  const suffix = `${Date.now()}-${Math.floor(Math.random() * 1e6)}`;
  const email = `e2e-${suffix}@example.com`;
  const password = "secret123";

  await page.getByRole("tab", { name: "Create account" }).click();
  const form = page.getByRole("form", { name: "Create account" });
  await form.getByLabel("Full name").fill(name);
  await form.getByLabel("Email").fill(email);
  await form.getByLabel("Phone").fill("+37493333444");
  await form.getByLabel("Password").fill(password);
  await form.getByRole("button", { name: "Create account" }).click();
  await expect(page.getByText(new RegExp(`Signed in as ${name}`))).toBeVisible();

  return { email, password, name };
}

export async function registerCustomerViaApi(
  request: APIRequestContext,
  apiBase: string,
) {
  const email = `api-${Date.now()}-${Math.floor(Math.random() * 1e6)}@example.com`;
  const res = await request.post(`${apiBase}/api/auth/register`, {
    data: {
      fullName: "E2E Customer",
      email,
      phoneNumber: "+37490000000",
      password: "secret123",
    },
  });
  expect(res.ok()).toBeTruthy();
  const body = await res.json();
  return { token: body.token as string, email, auth: body };
}

/**
 * Registers a customer through the API and stores the session the way the
 * storefront does, so the page starts signed in without going through the UI.
 */
export async function signInCustomerViaApi(
  page: Page,
  request: APIRequestContext,
  apiBase: string,
) {
  const customer = await registerCustomerViaApi(request, apiBase);
  await page.addInitScript((auth) => {
    window.localStorage.setItem("foodme.customer.auth", JSON.stringify(auth));
  }, customer.auth);
  return customer;
}

export async function placeTakeawayOrderViaApi(
  request: APIRequestContext,
  apiBase: string,
  customerToken: string,
) {
  const chefs = await (await request.get(`${apiBase}/api/chef/active?page=0&size=12`)).json();
  const chef = chefs.exploreChefResponseDtoList[0];
  const detail = await (await request.get(`${apiBase}/api/chef/${chef.id}`)).json();
  const dish = detail.dishes[0];
  const res = await request.post(`${apiBase}/api/order`, {
    headers: { Authorization: `Bearer ${customerToken}` },
    data: {
      chefId: chef.id,
      receiverName: "E2E Customer",
      receiverPhoneNumber: "+37490000000",
      receiverEmail: "e2e-customer@example.com",
      paymentType: "CASH",
      deliveryMethod: "TAKEAWAY",
      note: "e2e cancellation",
      createOrderDishes: [{ dishId: dish.id, quantity: 1 }],
    },
  });
  expect(res.ok()).toBeTruthy();
  return (await res.json()) as { number: string; status: string };
}

/** Moves an order to ACCEPTED through the admin API, as the kitchen would. */
export async function acceptOrderViaAdminApi(
  request: APIRequestContext,
  apiBase: string,
  orderNumber: string,
) {
  // Seeded local admin; override with E2E_ADMIN_USERNAME / E2E_ADMIN_PASSWORD.
  const login = await request.post(`${apiBase}/admin/auth/login`, {
    data: {
      username: process.env.E2E_ADMIN_USERNAME || "admin",
      password: process.env.E2E_ADMIN_PASSWORD || "admin123",
    },
  });
  expect(login.ok()).toBeTruthy();
  const { token } = await login.json();
  const headers = { Authorization: `Bearer ${token}` };

  const orders = await (await request.get(`${apiBase}/admin/order?page=0&size=50`, { headers })).json();
  const order = (orders.list as { id: number; number: string }[]).find((o) => o.number === orderNumber);
  expect(order).toBeTruthy();

  const res = await request.patch(`${apiBase}/admin/order/${order!.id}/status`, {
    headers,
    data: { status: "ACCEPTED" },
  });
  expect(res.ok()).toBeTruthy();
}
