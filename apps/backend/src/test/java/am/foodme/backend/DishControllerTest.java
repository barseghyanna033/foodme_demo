package am.foodme.backend;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
class DishControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @Test
    void getActiveDishesForChef_returnsOnlyActiveDishes() throws Exception {
        mockMvc.perform(get("/api/dish/1/active").param("page", "0").param("size", "50"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.dishDtoList").isArray())
                .andExpect(jsonPath("$.count").value(2));
    }

    // FM-FLAKE-03
    @Test
    void getActiveDishesForChef_firstResultIsLavashWrap() throws Exception {
        mockMvc.perform(get("/api/dish/1/active").param("page", "0").param("size", "50"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.dishDtoList[0].nameEn").value("Lavash Wrap"));
    }

    // FOOD-1
    @Test
    void getActiveDishesForChef_returnsDishWithNoArmenianName() throws Exception {
        mockMvc.perform(get("/api/dish/2/active").param("page", "0").param("size", "50"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.dishDtoList[?(@.id == 5)].nameEn").value("Missing Armenian Name"));
    }
}
