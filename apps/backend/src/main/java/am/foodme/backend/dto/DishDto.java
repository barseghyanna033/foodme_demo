package am.foodme.backend.dto;

import am.foodme.backend.model.Dish;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;
import java.util.List;
import java.util.stream.Collectors;

@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class DishDto {
    private List<DishAdditionDto> additions;
    private Long id;
    private String nameEn;
    private String nameHy;
    private String nameRu;
    private String descriptionEn;
    private Double price;
    private String url;
    private String portionEn;
    private String portionHy;
    private String portionRu;
    private String status;
    private int minimumOrderCount;
    private Integer priorityIndex;
    private Long chefId;
    private DishTagDto dishTagDto;

    public static DishDto mapEntityToDto(Dish entity) {
        if (entity == null) {
            return null;
        }
        DishDto dto = new DishDto();
        dto.setId(entity.getId());
        dto.setNameEn(entity.getNameEn());
        dto.setNameHy(entity.getNameAm() != null ? entity.getNameAm().trim() : null);
        dto.setNameRu(entity.getNameRu());
        dto.setDescriptionEn(entity.getDescriptionEn());
        dto.setPrice(entity.getPrice());
        dto.setUrl(entity.getUrl());
        dto.setPortionEn(entity.getPortionEn());
        dto.setPortionHy(entity.getPortionAm());
        dto.setPortionRu(entity.getPortionRu());
        dto.setStatus(entity.getStatus());
        dto.setMinimumOrderCount(entity.getMinimumOrderCount());
        dto.setPriorityIndex(entity.getPriorityIndex());
        dto.setChefId(entity.getChef() != null ? entity.getChef().getId() : null);
        dto.setDishTagDto(DishTagDto.mapEntityToDto(entity.getDishTag()));
        if (entity.getAdditions() != null) {
            dto.setAdditions(entity.getAdditions().stream().map(a -> {
                DishAdditionDto add = new DishAdditionDto();
                add.setId(a.getId());
                add.setNameEn(a.getNameEn());
                add.setNameAm(a.getNameAm());
                add.setNameRu(a.getNameRu());
                add.setPrice(a.getPrice());
                return add;
            }).toList());
        }
        return dto;
    }

    public static Dish mapDtoToEntity(DishDto dto) {
        if (dto == null) {
            return null;
        }
        Dish entity = new Dish();
        entity.setId(dto.getId());
        entity.setNameEn(dto.getNameEn());
        entity.setNameAm(dto.getNameHy());
        entity.setNameRu(dto.getNameRu());
        entity.setDescriptionEn(dto.getDescriptionEn());
        entity.setPrice(dto.getPrice());
        entity.setUrl(dto.getUrl());
        entity.setPortionEn(dto.getPortionEn());
        entity.setPortionAm(dto.getPortionHy());
        entity.setPortionRu(dto.getPortionRu());
        entity.setStatus(dto.getStatus());
        entity.setMinimumOrderCount(dto.getMinimumOrderCount());
        entity.setPriorityIndex(dto.getPriorityIndex());
        entity.setDishTag(DishTagDto.mapDtoToEntity(dto.getDishTagDto()));
        return entity;
    }
}
