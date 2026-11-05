# Problema 1 - Robot de rescate
# Integrantes: [nombre 1], [nombre 2]
#
# MAPA SVG escrito por FRAGMENTOS: cada elemento (una casilla, un segmento de la ruta,
# un renglón de la leyenda) es una línea que se escribe sola. Nunca se arma un string
# con todo el documento. Todo texto que viene de los archivos (nombres de terreno,
# símbolos) pasa por escapar_xml/1 antes de entrar al SVG.
#
# Atención con los ejes: una posición es {fila, columna}, pero en el dibujo
#   x depende de la COLUMNA  y  y depende de la FILA.

defmodule RescateSvg do
  @lado 40                      # cada casilla mide 40 x 40 píxeles
  @ancho_minimo 420             # para que la leyenda quepa aunque el mapa sea pequeño
  @alto_renglon_leyenda 24
  @simbolo_inicio "S"
  @simbolo_meta "M"

  @color_pared "#4a4a4a"
  @color_inicio "#8ad08a"
  @color_meta "#f2c14e"
  @color_ruta "#d62728"
  # Colores para los demás terrenos transitables (se asignan en orden de símbolo)
  @paleta ["#efe6c8", "#c9a66b", "#9ecae1", "#b5d99c", "#d4a5d4", "#f4b6a6"]

  # ---------- El "qué" ----------

  @doc """
  Escribe ruta_optima.svg. "recorrido" es el de menor energía (%Recorrido{}),
  o nil si no existe ninguno: entonces se dibuja el mapa y la leyenda "sin recorrido".
  """
  def escribir_svg(recorrido, datos, ruta) do
    colores = colores_por_simbolo(datos.terrenos)
    terrenos_ordenados = datos.terrenos |> Map.values() |> Enum.sort_by(& &1.simbolo)
    ancho = max(datos.columnas * @lado, @ancho_minimo)
    alto = datos.filas * @lado + 16 + (length(terrenos_ordenados) + 1) * @alto_renglon_leyenda + 8

    [
      lineas_de_cabecera(ancho, alto),
      lineas_de_casillas(datos, colores),
      lineas_de_ruta(recorrido),
      lineas_de_leyenda(terrenos_ordenados, colores, recorrido, datos),
      ["</svg>\n"]
    ]
    |> Stream.concat()
    |> Enum.into(File.stream!(ruta, [:write]))
  end

  # ---------- El "cómo" ----------

  defp lineas_de_cabecera(ancho, alto) do
    [
      ~s(<?xml version="1.0" encoding="UTF-8"?>\n),
      ~s(<svg xmlns="http://www.w3.org/2000/svg" width="#{ancho}" height="#{alto}" viewBox="0 0 #{ancho} #{alto}" font-family="Arial, sans-serif">\n),
      "<title>Ruta de menor energía del robot de rescate</title>\n",
      ~s(<rect x="0" y="0" width="#{ancho}" height="#{alto}" fill="#ffffff"/>\n)
    ]
  end

  # Una línea por casilla, ordenadas por fila y columna.
  # Stream.map: cada línea se produce cuando se escribe, no antes.
  defp lineas_de_casillas(datos, colores) do
    datos.edificio
    |> Enum.sort()
    |> Stream.map(fn {posicion, simbolo} ->
      linea_de_casilla(posicion, simbolo, Map.get(datos.terrenos, simbolo), colores)
    end)
  end

  defp linea_de_casilla({fila, columna}, simbolo, terreno, colores) do
    x = columna * @lado
    y = fila * @lado
    descripcion = "#{simbolo}: #{terreno.nombre}, posición (#{fila},#{columna}), costo #{terreno.costo}"

    "<g><title>#{escapar_xml(descripcion)}</title>" <>
      ~s(<rect x="#{x}" y="#{y}" width="#{@lado}" height="#{@lado}" fill="#{color_de(terreno, colores)}" stroke="#999999"/>) <>
      ~s(<text x="#{x + div(@lado, 2)}" y="#{y + 26}" text-anchor="middle" font-size="18" fill="#{color_del_texto(terreno)}">#{escapar_xml(simbolo)}</text></g>\n)
  end

  # Pattern matching sobre la struct: primero se decide por pared, luego por rol (S, M)
  defp color_de(%Terreno{transitable: false}, _colores), do: @color_pared
  defp color_de(%Terreno{simbolo: @simbolo_inicio}, _colores), do: @color_inicio
  defp color_de(%Terreno{simbolo: @simbolo_meta}, _colores), do: @color_meta
  defp color_de(%Terreno{simbolo: simbolo}, colores), do: Map.fetch!(colores, simbolo)

  defp color_del_texto(%Terreno{transitable: false}), do: "#dddddd"
  defp color_del_texto(_terreno), do: "#222222"

  # Terrenos transitables que no son S ni M: cada uno recibe un color de la paleta.
  # Los colores salen de terrenos.csv (no de símbolos escritos a mano en el código).
  defp colores_por_simbolo(terrenos) do
    terrenos
    |> Map.values()
    |> Enum.filter(fn terreno ->
      terreno.transitable and terreno.simbolo != @simbolo_inicio and terreno.simbolo != @simbolo_meta
    end)
    |> Enum.sort_by(& &1.simbolo)
    |> Enum.with_index()
    |> Map.new(fn {terreno, indice} ->
      {terreno.simbolo, Enum.at(@paleta, rem(indice, length(@paleta)))}
    end)
  end

  # ----- la ruta: un segmento por movimiento y dos marcadores -----

  defp lineas_de_ruta(nil), do: []

  defp lineas_de_ruta(%Recorrido{posiciones: posiciones}) do
    segmentos =
      posiciones
      |> Stream.chunk_every(2, 1, :discard)
      |> Stream.map(fn [desde, hasta] -> linea_de_segmento(desde, hasta) end)

    [primera | _resto] = posiciones
    ultima = List.last(posiciones)

    Stream.concat([segmentos, [marcador(primera, "#ffffff"), marcador(ultima, @color_ruta)]])
  end

  defp linea_de_segmento({fila_a, columna_a}, {fila_b, columna_b}) do
    ~s(<line x1="#{centro(columna_a)}" y1="#{centro(fila_a)}" x2="#{centro(columna_b)}" y2="#{centro(fila_b)}" stroke="#{@color_ruta}" stroke-width="5" stroke-linecap="round"/>\n)
  end

  defp marcador({fila, columna}, relleno) do
    ~s(<circle cx="#{centro(columna)}" cy="#{centro(fila)}" r="8" fill="#{relleno}" stroke="#{@color_ruta}" stroke-width="3"/>\n)
  end

  # Centro de una casilla (sirve tanto para filas como para columnas)
  defp centro(indice), do: indice * @lado + div(@lado, 2)

  # ----- leyenda: un renglón por terreno y uno para la ruta -----

  defp lineas_de_leyenda(terrenos, colores, recorrido, datos) do
    base = datos.filas * @lado + 16

    renglones_de_terrenos =
      terrenos
      |> Stream.with_index()
      |> Stream.map(fn {terreno, indice} ->
        renglon_de_terreno(terreno, colores, base + indice * @alto_renglon_leyenda)
      end)

    y_ruta = base + length(terrenos) * @alto_renglon_leyenda
    Stream.concat(renglones_de_terrenos, [renglon_de_ruta(recorrido, y_ruta)])
  end

  defp renglon_de_terreno(terreno, colores, y) do
    detalle = if terreno.transitable, do: "costo #{terreno.costo}", else: "no transitable"
    texto = "#{terreno.simbolo} = #{terreno.nombre} (#{detalle})"

    ~s(<rect x="10" y="#{y}" width="16" height="16" fill="#{color_de(terreno, colores)}" stroke="#999999"/>) <>
      ~s(<text x="34" y="#{y + 13}" font-size="13" fill="#222222">#{escapar_xml(texto)}</text>\n)
  end

  defp renglon_de_ruta(nil, y) do
    ~s(<text x="10" y="#{y + 13}" font-size="14" font-weight="bold" fill="#{@color_ruta}">sin recorrido</text>\n)
  end

  defp renglon_de_ruta(%Recorrido{} = recorrido, y) do
    texto = "Ruta de menor energía: #{recorrido.energia} de energía, #{RescateSalidas.movimientos(recorrido)} movimientos"

    ~s(<line x1="10" y1="#{y + 8}" x2="26" y2="#{y + 8}" stroke="#{@color_ruta}" stroke-width="5" stroke-linecap="round"/>) <>
      ~s(<text x="34" y="#{y + 13}" font-size="13" fill="#222222">#{escapar_xml(texto)}</text>\n)
  end

  # ----- escape de texto XML -----

  # El "&" va PRIMERO: si no, se escaparía también el "&" de los escapes ya hechos.
  defp escapar_xml(texto) do
    texto
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
    |> String.replace("\"", "&quot;")
    |> String.replace("'", "&apos;")
  end
end
