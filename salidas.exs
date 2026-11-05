# Problema 1 - Robot de rescate
# Integrantes: [nombre 1], [nombre 2]
#
# ESCRITURA PROGRESIVA de los archivos de salida: se arma un Stream de líneas
# (cada una termina en "\n") y Enum.into(File.stream!(ruta, [:write])) las escribe
# una por una. Nunca se forma un único string con todo el documento.
# Las funciones que arman texto son puras; solo las "escribir_*" tocan el disco.
# (El SVG está en svg.exs porque es largo.)

defmodule RescateSalidas do
  # ---------- validacion_edificio.txt ----------

  def escribir_validacion([], ruta) do
    ["Validación correcta: no se encontraron errores.\n"]
    |> Enum.into(File.stream!(ruta, [:write]))
  end

  def escribir_validacion(errores, ruta) do
    errores
    |> Stream.map(fn {ubicacion, mensaje} -> "#{ubicacion}: #{mensaje}\n" end)
    |> Enum.into(File.stream!(ruta, [:write]))
  end

  # ---------- expansion_energia.txt ----------

  @doc """
  Escribe los pasos distintos de la relajación, el índice de estabilización
  y el costo de la meta. Posiciones ordenadas por fila y columna.
  """
  def escribir_expansion(relajacion, datos, ruta) do
    lineas_de_pasos =
      relajacion.estados
      |> Stream.with_index()
      |> Stream.map(fn {estado, paso} -> linea_de_paso(estado, paso) end)

    lineas_finales = [
      linea_de_estabilizacion(relajacion.indice),
      linea_de_meta(relajacion.estado_final, datos)
    ]

    lineas_de_pasos
    |> Stream.concat(lineas_finales)
    |> Enum.into(File.stream!(ruta, [:write]))
  end

  # "Paso 1: (1,1)=0 | (1,2)=1 | (2,1)=1"
  # Enum.sort sobre un mapa lo deja ordenado por {fila, columna}
  defp linea_de_paso(estado, paso) do
    celdas =
      estado
      |> Enum.sort()
      |> Enum.map_join(" | ", fn {posicion, costo} -> "#{texto_posicion(posicion)}=#{costo}" end)

    "Paso #{paso}: #{celdas}\n"
  end

  defp linea_de_estabilizacion(indice) do
    "Índice de estabilización: #{indice} (el paso #{indice + 1} es igual al paso #{indice})\n"
  end

  defp linea_de_meta(estado_final, %{meta: meta, presupuesto: presupuesto}) do
    case Map.fetch(estado_final, meta) do
      {:ok, costo} ->
        "Costo mínimo para llegar a la meta #{texto_posicion(meta)}: #{costo}\n"

      :error ->
        "La meta #{texto_posicion(meta)} no es alcanzable con B = #{presupuesto}: se omite la enumeración de recorridos.\n"
    end
  end

  # ---------- recorridos_rescate.csv + acumuladores ----------

  @doc """
  UN solo recorrido de la lista de recorridos (un solo Enum.reduce):
    - escribe la fila del CSV de cada recorrido apenas se produce
    - actualiza los acumuladores (total, menos movimientos, menor energía, con empates)
  Devuelve los acumuladores finales. No guarda los recorridos en una lista.
  """
  def escribir_recorridos(recorridos, ruta) do
    File.open!(ruta, [:write, :utf8], fn archivo ->
      IO.write(archivo, "id;movimientos;energia;posiciones\n")

      recorridos
      |> Stream.with_index(1)
      |> Enum.reduce(acumulador_inicial(), fn {recorrido, id}, acumulado ->
        IO.write(archivo, fila_csv(id, recorrido))
        actualizar(acumulado, id, recorrido)
      end)
      |> en_orden_de_aparicion()
    end)
  end

  defp acumulador_inicial do
    %{total: 0, menos_movimientos: nil, menor_energia: nil}
  end

  # Cada "mejor" es nil (aún no hay ninguno) o {valor, [{id, recorrido}, ...]}
  defp actualizar(acumulado, id, recorrido) do
    entrada = {id, recorrido}

    %{
      acumulado
      | total: acumulado.total + 1,
        menos_movimientos:
          actualizar_mejores(acumulado.menos_movimientos, movimientos(recorrido), entrada),
        menor_energia:
          actualizar_mejores(acumulado.menor_energia, recorrido.energia, entrada)
    }
  end

  # El primero que llega queda como mejor
  defp actualizar_mejores(nil, valor, entrada), do: {valor, [entrada]}

  # Uno MEJOR (menor): reemplaza a todos los anteriores
  defp actualizar_mejores({mejor, _entradas}, valor, entrada) when valor < mejor do
    {valor, [entrada]}
  end

  # Uno IGUAL: empate, se agrega a los anteriores (queda al revés; se arregla al final)
  defp actualizar_mejores({mejor, entradas}, valor, entrada) when valor == mejor do
    {mejor, [entrada | entradas]}
  end

  # Uno peor: no cambia nada
  defp actualizar_mejores(mejores, _valor, _entrada), do: mejores

  defp en_orden_de_aparicion(acumulado) do
    %{
      acumulado
      | menos_movimientos: invertir_empates(acumulado.menos_movimientos),
        menor_energia: invertir_empates(acumulado.menor_energia)
    }
  end

  defp invertir_empates(nil), do: nil
  defp invertir_empates({valor, entradas}), do: {valor, Enum.reverse(entradas)}

  # "1;3;5;(1,1)->(1,2)->(1,3)->(1,4)"  (dentro del campo no hay ";" porque es el separador)
  defp fila_csv(id, recorrido) do
    "#{id};#{movimientos(recorrido)};#{recorrido.energia};#{texto_recorrido(recorrido)}\n"
  end

  @doc "Movimientos = posiciones - 1 (la primera posición es S, de donde se parte)."
  def movimientos(%Recorrido{posiciones: posiciones}), do: length(posiciones) - 1

  @doc "Primer recorrido de menor energía (el primero encontrado en caso de empate), o nil."
  def primer_recorrido_de_menor_energia(%{menor_energia: nil}), do: nil

  def primer_recorrido_de_menor_energia(%{menor_energia: {_energia, [{_id, recorrido} | _]}}) do
    recorrido
  end

  # ---------- resumen_rescate.txt (y pantalla) ----------

  @doc "Líneas del resumen. Sirven para escribir el archivo Y para mostrarlas en pantalla."
  def lineas_resumen(acumulado, datos) do
    [
      "RESUMEN DE RESCATE\n",
      "Edificio: #{datos.filas} filas x #{datos.columnas} columnas | Energía máxima B = #{datos.presupuesto}\n",
      "Total de recorridos válidos: #{acumulado.total}\n"
    ] ++ lineas_de_mejores(acumulado, datos)
  end

  defp lineas_de_mejores(%{total: 0}, datos) do
    ["No existe ningún recorrido válido de S a M con B = #{datos.presupuesto}.\n"]
  end

  defp lineas_de_mejores(acumulado, _datos) do
    {minimo_movimientos, con_menos_movimientos} = acumulado.menos_movimientos
    {minima_energia, con_menor_energia} = acumulado.menor_energia

    ["\nRecorridos con menos movimientos (#{minimo_movimientos} movimientos): #{length(con_menos_movimientos)}\n"] ++
      lineas_de_recorridos(con_menos_movimientos, :energia) ++
      ["\nRecorridos con menor energía (#{minima_energia}): #{length(con_menor_energia)}\n"] ++
      lineas_de_recorridos(con_menor_energia, :movimientos)
  end

  # Cada recorrido empatado, con el dato que NO es el que se está comparando
  defp lineas_de_recorridos(entradas, :energia) do
    Enum.map(entradas, fn {id, recorrido} ->
      "  - id #{id}: energía #{recorrido.energia}, #{texto_recorrido(recorrido)}\n"
    end)
  end

  defp lineas_de_recorridos(entradas, :movimientos) do
    Enum.map(entradas, fn {id, recorrido} ->
      "  - id #{id}: #{movimientos(recorrido)} movimientos, #{texto_recorrido(recorrido)}\n"
    end)
  end

  def escribir_resumen(lineas, ruta) do
    Enum.into(lineas, File.stream!(ruta, [:write]))
  end

  # "(1,1)->(1,2)->(1,3)->(1,4)"
  defp texto_recorrido(%Recorrido{posiciones: posiciones}) do
    Enum.map_join(posiciones, "->", &texto_posicion/1)
  end

  @doc "{1, 4} se escribe (1,4)"
  def texto_posicion({fila, columna}), do: "(#{fila},#{columna})"
end
