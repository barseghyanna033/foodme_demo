const OrderStatus = {
    NEW: 'NEW',
    ACCEPTED: 'ACCEPTED',
    DELIVERED: 'DELIVERED',
    REJECTED: 'REJECTED',
    CANCELLED: 'CANCELLED',
};

const OrderStatusColors = {
    [OrderStatus.NEW]: 'info',
    [OrderStatus.ACCEPTED]: 'warning',
    [OrderStatus.DELIVERED]: 'success',
    [OrderStatus.REJECTED]: 'error',
    [OrderStatus.CANCELLED]: 'default',
};

// Statuses whose orders are excluded from revenue.
const NonRevenueOrderStatuses = [OrderStatus.REJECTED, OrderStatus.CANCELLED];

// Allowed forward transitions per current status
const OrderStatusTransitions = {
    [OrderStatus.NEW]: [OrderStatus.ACCEPTED, OrderStatus.REJECTED],
    [OrderStatus.ACCEPTED]: [OrderStatus.DELIVERED, OrderStatus.REJECTED],
    [OrderStatus.DELIVERED]: [],
    [OrderStatus.REJECTED]: [],
    // Customer-cancelled orders are final.
    [OrderStatus.CANCELLED]: [],
};

export { OrderStatus, OrderStatusColors, OrderStatusTransitions, NonRevenueOrderStatuses };
