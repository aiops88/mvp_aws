package festivos.api.core.servicios;

import java.util.List;
import festivos.api.dominio.entidades.*;


public interface IPaisServicio {

    public List<Pais> listar();

    public Pais obtener(int id);

    public List<Pais> buscar(String nombre);

    public Pais agregar(Pais pais);

    public Pais modificar(Pais pais);

    public boolean eliminar(int id);

}
