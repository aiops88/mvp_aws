package festivos.api.aplicacion.servicios;

import java.util.List;

import org.springframework.stereotype.Service;
import org.springframework.data.domain.Sort;

import festivos.api.core.servicios.*;
import festivos.api.dominio.entidades.*;
import festivos.api.infraestructura.repositorios.*;

@Service
public class PaisServicio implements IPaisServicio {

    private IPaisRepositorio repositorio;

    public PaisServicio(IPaisRepositorio repositorio) {
        this.repositorio = repositorio;
    }

    @Override
    public List<Pais> listar() {
        return repositorio.findAll(Sort.by(Sort.Direction.ASC, "nombre"));
    }

    @Override
    public Pais obtener(int id) {
        return repositorio.findById(id).isEmpty() ? null : repositorio.findById(id).get();
    }

    @Override
    public List<Pais> buscar(String nombre) {
        return repositorio.buscar(nombre);
    }

    @Override
    public Pais agregar(Pais pais) {
        pais.setId(0);
        return repositorio.save(pais);
    }

    @Override
    public Pais modificar(Pais pais) {
        if (repositorio.findById(pais.getId()).isEmpty())
            return null;
        return repositorio.save(pais);
    }

    @Override
    public boolean eliminar(int id) {
        try {
            repositorio.deleteById(id);
            return true;
        } catch (Exception ex) {
            return false;
        }
    }

}
