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
class ChefControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @Test
    void getActiveChefs_returnsActiveChefsOnly() throws Exception {
        mockMvc.perform(get("/api/chef/active").param("page", "0").param("size", "12"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.exploreChefResponseDtoList").isArray())
                .andExpect(jsonPath("$.count").value(2));
    }

    @Test
    void getChefById_returnsChefWithDishes() throws Exception {
        mockMvc.perform(get("/api/chef/1"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.id").value(1))
                .andExpect(jsonPath("$.username").value("marta-k"))
                .andExpect(jsonPath("$.dishes").isArray());
    }

    // FOOD-1
    @Test
    void getChefById_returnsMenuWhenDishHasNoArmenianName() throws Exception {
        mockMvc.perform(get("/api/chef/2"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.dishes[?(@.id == 5)].nameEn").value("Missing Armenian Name"));
    }
}
