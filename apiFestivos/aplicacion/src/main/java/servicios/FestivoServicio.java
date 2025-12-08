package festivos.api.aplicacion.servicios;

import java.time.DayOfWeek;
import java.time.LocalDate;
import java.time.temporal.TemporalAdjusters;
import java.util.ArrayList;
import java.util.List;

import org.springframework.stereotype.Service;
import org.springframework.data.domain.Sort;

import festivos.api.aplicacion.servicios.ServicioFechas;
import festivos.api.core.servicios.*;
import festivos.api.dominio.entidades.*;
import festivos.api.dominio.DTOs.*;
import festivos.api.infraestructura.repositorios.*;

@Service
public class FestivoServicio implements IFestivoServicio {

    private IFestivoRepositorio repositorio;

    public FestivoServicio(IFestivoRepositorio repositorio) {
        this.repositorio = repositorio;
    }

    @Override
    public List<Festivo> listar() {
        return repositorio.findAll(Sort.by(Sort.Direction.ASC, "nombre"));
    }

    @Override
    public Festivo obtener(int id) {
        return repositorio.findById(id).isEmpty() ? null : repositorio.findById(id).get();
    }

    @Override
    public List<Festivo> buscar(String nombre) {
        return repositorio.buscar(nombre);
    }

    @Override
    public Festivo agregar(Festivo festivo) {
        festivo.setId(0);
        return repositorio.save(festivo);
    }

    @Override
    public Festivo modificar(Festivo festivo) {
        if (repositorio.findById(festivo.getId()).isEmpty())
            return null;
        return repositorio.save(festivo);
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

    @Override
    public boolean verificar(int idPais, LocalDate fecha) {
        var fechasFestivos = getFechasFestivos(idPais, fecha.getYear());
        return fechasFestivos.stream().anyMatch(f -> f.getFecha().equals(fecha));
    }

    private List<FestivoDto> getFechasFestivos(int idPais, int año) {
        List<FestivoDto> fechasFestivos = new ArrayList();
        var festivos = repositorio.listarPorPais(idPais);
        for (var festivo : festivos) {
            LocalDate fechaFestivo;
            switch (festivo.getTipo().getId()) {
                case 1: // Fijo
                    fechaFestivo = LocalDate.of(año, festivo.getMes(), festivo.getDia());
                    fechasFestivos.add(new FestivoDto(festivo.getNombre(), fechaFestivo));
                    break;

                case 2: // Ley Puente Festivo (según Ley 51 de 1983)
                    fechaFestivo = ServicioFechas.siguienteLunes(LocalDate.of(año, festivo.getMes(), festivo.getDia()));
                    fechasFestivos.add(new FestivoDto(festivo.getNombre(), fechaFestivo));
                    break;
                case 3:
                    fechaFestivo = ServicioFechas.agregarDias(ServicioFechas.getPascua(año), festivo.getDiasPascua());
                    fechasFestivos.add(new FestivoDto(festivo.getNombre(), fechaFestivo));
                    break;
                case 4:
                    fechaFestivo = ServicioFechas.siguienteLunes(
                            ServicioFechas.agregarDias(ServicioFechas.getPascua(año), festivo.getDiasPascua()));
                    fechasFestivos.add(new FestivoDto(festivo.getNombre(), fechaFestivo));
                    break;
            }
        }
        return fechasFestivos;
    }

    @Override
    public List<FestivoDto> listar(int idPais, int año) {
        return getFechasFestivos(idPais, año);
    }

}
