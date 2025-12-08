package festivos.api.presentacion.controladores;

import java.time.DateTimeException;
import java.time.LocalDate;
import java.util.List;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestMethod;
import org.springframework.web.bind.annotation.RestController;

import festivos.api.dominio.entidades.*;
import festivos.api.dominio.DTOs.*;
import festivos.api.core.servicios.*;

@RestController
@RequestMapping("/api/festivos")
public class FestivoControlador {
    private IFestivoServicio servicio;

    public FestivoControlador(IFestivoServicio servicio) {
        this.servicio = servicio;
    }

    @RequestMapping(value = "/listar", method = RequestMethod.GET)
    public List<Festivo> listar() {
        return servicio.listar();
    }

    @RequestMapping(value = "/obtener/{id}", method = RequestMethod.GET)
    public Festivo obtener(@PathVariable int id) {
        return servicio.obtener(id);
    }

    @RequestMapping(value = "/buscar/{nombre}", method = RequestMethod.GET)
    public List<Festivo> buscar(@PathVariable String nombre) {
        return servicio.buscar(nombre);
    }

    @RequestMapping(value = "/agregar", method = RequestMethod.POST)
    public Festivo agregar(@RequestBody Festivo pais) {
        return servicio.agregar(pais);
    }

    @RequestMapping(value = "/modificar", method = RequestMethod.PUT)
    public Festivo modificar(@RequestBody Festivo pais) {
        return servicio.modificar(pais);
    }

    @RequestMapping(value = "/eliminar/{id}", method = RequestMethod.DELETE)
    public boolean eliminar(@PathVariable int id) {
        return servicio.eliminar(id);
    }

    @RequestMapping(value = "/verificar/{idPais}/{año}/{mes}/{dia}", method = RequestMethod.GET)
    public ResponseEntity<?>  verificar(@PathVariable int idPais, @PathVariable int año, @PathVariable int mes,
            @PathVariable int dia) {
        try {
            LocalDate fecha = LocalDate.of(año, mes, dia);
            boolean esFestivo = servicio.verificar(idPais, fecha);
            return ResponseEntity.ok(esFestivo);
        } catch (DateTimeException e) {
            return ResponseEntity.badRequest().body("Fecha inválida: " + e.getMessage());
        }
    }

    @RequestMapping(value = "/listar/{idPais}/{año}", method = RequestMethod.GET)
    public List<FestivoDto> listar(@PathVariable int idPais, @PathVariable int año) {
        return servicio.listar(idPais, año);
    }

}
