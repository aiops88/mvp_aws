package festivos.api.aplicacion.servicios;

import java.time.DayOfWeek;
import java.time.LocalDate;

public class ServicioFechas {

    public static LocalDate getPascua(int año) {
        return agregarDias(getInicioSemanaSanta(año), 7);
    }

    public static LocalDate getInicioSemanaSanta(int año) {
        int a = año % 19;
        int b = año % 4;
        int c = año % 7;
        int d = (19 * a + 24) % 30;
        int dias = d + (2 * b + 4 * c + 6 * d + 5) % 7;

        int dia = 15 + dias;
        int mes = 3; // Marzo

        if (dia > 31) {
            dia -= 31;
            mes = 4; // Abril
        }

        return LocalDate.of(año, mes, dia);
    }

    public static LocalDate agregarDias(LocalDate fecha, int dias) {
        return fecha.plusDays(dias);
    }

    public static LocalDate siguienteLunes(LocalDate fecha) {
        DayOfWeek diaSemana = fecha.getDayOfWeek();
        int diasHastaLunes = (DayOfWeek.MONDAY.getValue() - diaSemana.getValue() + 7) % 7;
        return diasHastaLunes == 0 ? fecha : fecha.plusDays(diasHastaLunes);
    }
}
