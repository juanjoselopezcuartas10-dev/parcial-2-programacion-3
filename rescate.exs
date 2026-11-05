# Problema 1 - Robot de rescate con energía limitada y mapa SVG
# Integrantes: [nombre 1], [nombre 2]
#
# Uso (desde la carpeta problema1):
#   elixir rescate.exs pruebas/normal
# El argumento es la carpeta que contiene edificio.txt, terrenos.csv y bateria.txt.
# Las salidas se escriben en la subcarpeta "salida" de esa carpeta.
#
# Salidas (en la subcarpeta "salida"): validacion_edificio.txt, expansion_energia.txt,
# recorridos_rescate.csv, resumen_rescate.txt y ruta_optima.svg.
# Por pantalla solo se muestra el resumen.

Code.require_file("estructuras.exs", __DIR__)
Code.require_file("lectura.exs", __DIR__)
Code.require_file("validacion.exs", __DIR__)
Code.require_file("relajacion.exs", __DIR__)
Code.require_file("busqueda.exs", __DIR__)
Code.require_file("salidas.exs", __DIR__)
Code.require_file("svg.exs", __DIR__)

defmodule Rescate do
  # ---------- El "qué" ----------
  def main do
    obtener_carpeta()
    |> ejecutar()
    |> mostrar_resultado()
  end

  # ---------- El "cómo" (en el orden en que se usan) ----------

  # Sin argumento se usa el caso normal. Con argumento: elixir rescate.exs otra_carpeta
  defp obtener_carpeta do
    case System.argv() do
      [carpeta | _resto] -> carpeta
      [] -> Path.join(__DIR__, "pruebas/normal")
    end
  end

  # with: sigue mientras cada paso devuelva lo que está a la izquierda de "<-".
  # Si un paso devuelve otra cosa (un {:error, ...}), with se detiene y devuelve ESO.
  defp ejecutar(carpeta) do
    with {:ok, rutas} <- comprobar_archivos(carpeta),
         {:ok, entradas} <- leer_entradas(rutas),
         :ok <- validar_y_guardar(entradas, carpeta) do
      datos =
        RescateLectura.construir_datos(entradas.terrenos, entradas.edificio, entradas.bateria)

      {:ok, resolver(datos, carpeta)}
    end
  end

  defp comprobar_archivos(carpeta) do
    rutas = %{
      edificio: Path.join(carpeta, "edificio.txt"),
      terrenos: Path.join(carpeta, "terrenos.csv"),
      bateria: Path.join(carpeta, "bateria.txt")
    }

    faltantes =
      rutas
      |> Map.values()
      |> Enum.reject(&File.regular?/1)

    case faltantes do
      [] -> {:ok, rutas}
      _ -> {:error, {:faltan, faltantes}}
    end
  end

  # La lectura es perezosa; Enum.to_list va AQUÍ (fuera de las validaciones) porque
  # las validaciones recursivas necesitan listas.
  defp leer_entradas(rutas) do
    entradas = %{
      terrenos: rutas.terrenos |> RescateLectura.registros_terreno() |> Enum.to_list(),
      edificio: rutas.edificio |> RescateLectura.filas_edificio() |> Enum.to_list(),
      bateria: rutas.bateria |> RescateLectura.lineas_utiles() |> Enum.to_list()
    }

    {:ok, entradas}
  end

  defp validar_y_guardar(entradas, carpeta) do
    errores =
      RescateValidacion.validar(entradas.terrenos, entradas.edificio, entradas.bateria)

    ruta_reporte = Path.join(preparar_salida(carpeta), "validacion_edificio.txt")
    RescateSalidas.escribir_validacion(errores, ruta_reporte)

    case errores do
      [] -> :ok
      _ -> {:error, {:invalido, length(errores), ruta_reporte}}
    end
  end

  defp preparar_salida(carpeta) do
    salida = Path.join(carpeta, "salida")
    File.mkdir_p!(salida)
    salida
  end

  # Con las entradas ya válidas: relajación (filtro), enumeración y las tres salidas finales
  defp resolver(datos, carpeta) do
    salida = preparar_salida(carpeta)

    relajacion = RescateRelajacion.relajar(datos)
    RescateSalidas.escribir_expansion(relajacion, datos, Path.join(salida, "expansion_energia.txt"))

    acumulado =
      datos
      |> recorridos_a_enumerar(relajacion)
      |> RescateSalidas.escribir_recorridos(Path.join(salida, "recorridos_rescate.csv"))

    lineas_resumen = RescateSalidas.lineas_resumen(acumulado, datos)
    RescateSalidas.escribir_resumen(lineas_resumen, Path.join(salida, "resumen_rescate.txt"))

    acumulado
    |> RescateSalidas.primer_recorrido_de_menor_energia()
    |> RescateSvg.escribir_svg(datos, Path.join(salida, "ruta_optima.svg"))

    lineas_resumen
  end

  # Si la meta no tiene costo alcanzable, se OMITE la enumeración recursiva
  # (se entrega una lista vacía y el CSV queda solo con su encabezado)
  defp recorridos_a_enumerar(datos, relajacion) do
    case Map.fetch(relajacion.estado_final, datos.meta) do
      {:ok, _costo} -> RescateBusqueda.recorridos(datos)
      :error -> []
    end
  end

  # ÚNICA función que imprime el resultado: una cláusula por cada forma del resultado
  defp mostrar_resultado({:ok, lineas_resumen}) do
    Enum.each(lineas_resumen, &IO.write/1)
  end

  defp mostrar_resultado({:error, {:faltan, rutas}}) do
    IO.puts(:standard_error, "Aviso: no se encontraron los archivos requeridos:")
    Enum.each(rutas, fn ruta -> IO.puts(:standard_error, "  - #{ruta}") end)
  end

  defp mostrar_resultado({:error, {:invalido, cantidad, ruta_reporte}}) do
    IO.puts(:standard_error, "Se encontraron #{cantidad} error(es) de validación. No se inicia la búsqueda.")
    IO.puts(:standard_error, "Detalle en: #{ruta_reporte}")
  end
end

Rescate.main()
