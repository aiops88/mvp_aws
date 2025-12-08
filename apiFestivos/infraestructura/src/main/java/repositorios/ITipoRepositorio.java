package festivos.api.infraestructura.repositorios;

import java.util.List;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.stereotype.Repository;

import festivos.api.dominio.entidades.*;

@Repository
public interface ITipoRepositorio extends JpaRepository<Tipo, Integer> {

    @Query("SELECT t FROM Tipo t WHERE t.nombre LIKE '%' || ?1 || '%' ORDER BY t.nombre ASC")
    public List<Tipo> buscar(String nombre);

}
