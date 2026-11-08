package am.foodme.backend.service;

import am.foodme.backend.dto.AdminListResponseDto;
import am.foodme.backend.dto.OrderDto;
import am.foodme.backend.exceptionHandler.BadRequestException;
import am.foodme.backend.exceptionHandler.NotFoundException;
import am.foodme.backend.model.Order;
import am.foodme.backend.repository.OrderRepository;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Sort;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.stream.Collectors;

@Service
public class AdminOrderService {

    private static final Map<String, Set<String>> ALLOWED_TRANSITIONS = Map.of(
            "NEW", Set.of("ACCEPTED", "REJECTED"),
            "ACCEPTED", Set.of("DELIVERED", "REJECTED")
    );

    private final OrderRepository orderRepository;

    public AdminOrderService(OrderRepository orderRepository) {
        this.orderRepository = orderRepository;
    }

    @Transactional(readOnly = true)
    public AdminListResponseDto<OrderDto> list(int page, int size, String status) {
        PageRequest pageable = PageRequest.of(page, size, Sort.by(Sort.Direction.DESC, "createdAt"));
        Page<Order> orderPage = (status == null || status.isBlank())
                ? orderRepository.findAll(pageable)
                : orderRepository.findByStatus(status, pageable);
        List<OrderDto> list = orderPage.getContent().stream()
                .map(OrderDto::mapEntityToDto)
                .collect(Collectors.toList());
        return new AdminListResponseDto<>(list, orderPage.getTotalElements());
    }

    @Transactional(readOnly = true)
    public OrderDto getById(Long id) {
        return OrderDto.mapEntityToDto(findEntity(id));
    }

    @Transactional
    public OrderDto updateStatus(Long id, String newStatus, String rejectReason) {
        Order order = orderRepository.findByIdForUpdate(id)
                .orElseThrow(() -> new NotFoundException("Order " + id + " not found"));
        // CANCELLED has no entry, so a cancelled order cannot be moved to any other status.
        Set<String> allowed = ALLOWED_TRANSITIONS.get(order.getStatus());
        if (allowed == null || !allowed.contains(newStatus)) {
            throw new BadRequestException("Cannot transition order from " + order.getStatus() + " to " + newStatus);
        }
        order.setStatus(newStatus);
        if ("REJECTED".equals(newStatus)) {
            order.setRejectReason(rejectReason);
        }
        return OrderDto.mapEntityToDto(orderRepository.save(order));
    }

    private Order findEntity(Long id) {
        return orderRepository.findById(id)
                .orElseThrow(() -> new NotFoundException("Order " + id + " not found"));
    }
}
