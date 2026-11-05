package am.foodme.backend;

import am.foodme.backend.dto.DishDto;
import am.foodme.backend.model.Dish;
import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNull;

class DishDtoTest {

    // FOOD-1
    @Test
    void mapEntityToDto_keepsNullArmenianNameAsNull() {
        assertNull(mapDishWithArmenianName(null).getNameHy());
    }

    @Test
    void mapEntityToDto_trimsArmenianName() {
        assertEquals("Lavash", mapDishWithArmenianName("  Lavash  ").getNameHy());
    }

    @Test
    void mapEntityToDto_keepsArmenianNameWithoutExtraSpaces() {
        assertEquals("Lavash", mapDishWithArmenianName("Lavash").getNameHy());
    }

    private static DishDto mapDishWithArmenianName(String nameAm) {
        Dish dish = new Dish();
        dish.setNameAm(nameAm);
        return DishDto.mapEntityToDto(dish);
    }
}
