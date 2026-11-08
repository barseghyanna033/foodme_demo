package am.foodme.backend.repository;

import am.foodme.backend.model.Order;
import jakarta.persistence.LockModeType;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.Optional;

public interface OrderRepository extends JpaRepository<Order, Long> {
    Optional<Order> findByNumber(String number);

    Optional<Order> findByNumberAndCustomerId(String number, Long customerId);

    /**
     * Status changes (admin transitions and customer cancellation) must load the order
     * through one of these locking lookups inside a transaction, so concurrent changes
     * to the same order are serialised on its row lock.
     */
    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("SELECT o FROM Order o WHERE o.id = :id")
    Optional<Order> findByIdForUpdate(@Param("id") Long id);

    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("SELECT o FROM Order o WHERE o.number = :number AND o.customer.id = :customerId")
    Optional<Order> findByNumberAndCustomerIdForUpdate(@Param("number") String number,
                                                       @Param("customerId") Long customerId);

    Page<Order> findByStatus(String status, Pageable pageable);

    Page<Order> findByCustomerIdOrderByCreatedAtDesc(Long customerId, Pageable pageable);

    @Query(value = "SELECT nextval('foodme.order_number_seq')", nativeQuery = true)
    long nextOrderNumberSequenceValue();
}
