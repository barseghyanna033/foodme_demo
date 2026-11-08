import { test, expect } from "@playwright/test";
import {
  acceptOrderViaAdminApi,
  placeTakeawayOrderViaApi,
  registerCustomerViaApi,
  signInCustomerViaApi,
} from "./auth";

const API = process.env.VITE_API_BASE_URL || "http://localhost:8081";

// FOOD-3: customers can cancel an order from the tracking page until the kitchen accepts it.
test.describe("Order cancellation", () => {
  test("customer cancels a received order and sees it as cancelled everywhere", async ({
    page,
    request,
  }) => {
    const { token } = await signInCustomerViaApi(page, request, API);
    const order = await placeTakeawayOrderViaApi(request, API, token);

    await page.goto(`/tracking/${order.number}`);
    await expect(page.getByText("Order received")).toBeVisible();

    await page.getByRole("button", { name: "Cancel order" }).click();
    const dialog = page.getByRole("dialog", { name: `Cancel order ${order.number}?` });
    await expect(dialog).toBeVisible();
    await dialog.getByRole("button", { name: "Yes, cancel order" }).click();

    await expect(dialog).toBeHidden();
    await expect(page.getByText("Order cancelled")).toBeVisible();
    await expect(page.getByRole("button", { name: "Cancel order" })).toHaveCount(0);

    const tracked = await (await request.get(`${API}/api/order/number/${order.number}`)).json();
    expect(tracked.status).toBe("CANCELLED");

    await page.getByRole("link", { name: "All orders" }).click();
    await expect(page).toHaveURL(/\/orders$/);
    const row = page.getByRole("listitem").filter({ hasText: order.number });
    await expect(row.getByText("Cancelled", { exact: true })).toBeVisible();
  });

  test("keeping the order from the confirmation dialog leaves it received", async ({
    page,
    request,
  }) => {
    const { token } = await signInCustomerViaApi(page, request, API);
    const order = await placeTakeawayOrderViaApi(request, API, token);

    await page.goto(`/tracking/${order.number}`);
    await page.getByRole("button", { name: "Cancel order" }).click();
    await page.getByRole("button", { name: "Keep order" }).click();

    await expect(page.getByRole("dialog")).toBeHidden();
    await expect(page.getByText("Order received")).toBeVisible();
    await expect(page.getByRole("button", { name: "Cancel order" })).toBeVisible();
    const tracked = await (await request.get(`${API}/api/order/number/${order.number}`)).json();
    expect(tracked.status).toBe("NEW");
  });

  test("an order the kitchen accepted has no cancel option", async ({ page, request }) => {
    const { token } = await signInCustomerViaApi(page, request, API);
    const order = await placeTakeawayOrderViaApi(request, API, token);
    await acceptOrderViaAdminApi(request, API, order.number);

    await page.goto(`/tracking/${order.number}`);
    await expect(page.getByText("Preparing your order")).toBeVisible();
    await expect(page.getByRole("button", { name: "Cancel order" })).toHaveCount(0);
  });

  test("another signed-in customer sees no cancel option", async ({ page, request }) => {
    const { token: ownerToken } = await registerCustomerViaApi(request, API);
    const order = await placeTakeawayOrderViaApi(request, API, ownerToken);
    await signInCustomerViaApi(page, request, API);

    const ownershipCheck = page.waitForResponse(
      (res) => res.url().endsWith(`/api/customer/orders/${order.number}`) && res.request().method() === "GET",
    );
    await page.goto(`/tracking/${order.number}`);
    await expect(page.getByText("Order received")).toBeVisible();
    expect((await ownershipCheck).status()).toBe(404);
    await expect(page.getByRole("button", { name: "Cancel order" })).toHaveCount(0);
  });

  test("a signed-out visitor sees no cancel option", async ({ page, request }) => {
    const { token } = await registerCustomerViaApi(request, API);
    const order = await placeTakeawayOrderViaApi(request, API, token);

    await page.goto(`/tracking/${order.number}`);
    await expect(page.getByText("Order received")).toBeVisible();
    await expect(page.getByRole("button", { name: "Cancel order" })).toHaveCount(0);
  });
});
