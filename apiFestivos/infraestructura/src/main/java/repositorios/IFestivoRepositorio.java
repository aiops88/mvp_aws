package festivos.api.infraestructura.repositorios;

import java.util.List;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.stereotype.Repository;

import festivos.api.dominio.entidades.*;

@Repository
public interface IFestivoRepositorio extends JpaRepository<Festivo, Integer> {

    @Query("SELECT f FROM Festivo f WHERE f.nombre LIKE '%' || ?1 || '%' ORDER BY f.nombre ASC")
    public List<Festivo> buscar(String nombre);

    @Query("SELECT f FROM Festivo f WHERE f.pais.id=:idPais ORDER BY f.nombre ASC")
    public List<Festivo> listarPorPais(int idPais);

}
