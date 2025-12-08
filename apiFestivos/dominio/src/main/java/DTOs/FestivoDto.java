package festivos.api.dominio.DTOs;

import java.time.LocalDate;

import jakarta.persistence.Entity;
import jakarta.persistence.Id;


public class FestivoDto {

    private String pais;
    private LocalDate fecha;

    public FestivoDto() {
    }

    public FestivoDto(String pais, LocalDate fecha) {
        this.pais = pais;
        this.fecha = fecha;
    }

    public String getPais() {
        return pais;
    }

    public void setPais(String pais) {
        this.pais = pais;
    }

    public LocalDate getFecha() {
        return fecha;
    }

    public void setFecha(LocalDate fecha) {
        this.fecha = fecha;
    }

}
