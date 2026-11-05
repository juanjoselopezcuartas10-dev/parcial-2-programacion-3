# Problema 1 - Robot de rescate
#
# Lectura PEREZOSA de los archivos de entrada (File.stream!) y construcción de los datos.
# Aquí sí se permite Enum y Stream: las restricciones de "sin Enum ni Stream"
# aplican solo a las funciones de validación (validacion.exs).

defmodule RescateLectura do
  @simbolo_inicio "S"
  @simbolo_meta "M"

  # ---------- Lectura perezosa (devuelven un Stream, todavía no leen nada) ----------

  @doc """
  Lee un archivo línea por línea y devuelve un Stream de {numero_de_linea, texto}.
  Ignora líneas en blanco y comentarios (#), pero conserva el número de línea FÍSICA.
  """
  def lineas_utiles(ruta) do
    ruta
    |> File.stream!()
    |> Stream.with_index(1)                       # numerar ANTES de filtrar
    |> Stream.map(fn {linea, numero} -> {numero, limpiar(linea)} end)
    |> Stream.reject(fn {_numero, texto} -> vacia_o_comentario?(texto) end)
  end

  @doc "terrenos.csv: cada registro queda como {numero_de_linea, [campos]}."
  def registros_terreno(ruta) do
    ruta
    |> lineas_utiles()
    |> Stream.map(fn {numero, texto} -> {numero, separar_campos(texto)} end)
  end

  @doc "edificio.txt: cada fila queda como {numero_de_linea, [simbolos]}."
  def filas_edificio(ruta) do
    ruta
    |> lineas_utiles()
    |> Stream.map(fn {numero, texto} -> {numero, String.split(texto)} end)
  end

  # Quita el BOM (marca invisible que algunos editores de Windows añaden),
  # y los espacios y el \r del final de cada línea
  defp limpiar(linea) do
    linea
    |> String.trim_leading("\uFEFF")
    |> String.trim()
  end

  defp vacia_o_comentario?(""), do: true
  defp vacia_o_comentario?("#" <> _resto), do: true
  defp vacia_o_comentario?(_texto), do: false

  defp separar_campos(texto) do
    texto
    |> String.split(",")
    |> Enum.map(&String.trim/1)
  end

  # ---------- Construcción de los datos (solo se llama con entradas ya validadas) ----------

  @doc "Mapa %{\"L\" => %Terreno{...}} a partir de los registros de terrenos.csv."
  def construir_terrenos(registros) do
    Enum.into(registros, %{}, fn {_numero, [simbolo, nombre, transitable, costo]} ->
      terreno = %Terreno{
        simbolo: simbolo,
        nombre: nombre,
        transitable: transitable == "si",
        costo: String.to_integer(costo)
      }

      {simbolo, terreno}
    end)
  end

  @doc "Mapa %{{fila, columna} => simbolo}, con coordenadas desde 0."
  def construir_edificio(filas) do
    filas
    |> Enum.with_index()
    |> Enum.flat_map(fn {{_numero_linea, simbolos}, fila} ->
      simbolos
      |> Enum.with_index()
      |> Enum.map(fn {simbolo, columna} -> {{fila, columna}, simbolo} end)
    end)
    |> Map.new()
  end

  @doc "Lee el entero B (la primera línea de datos de bateria.txt)."
  def leer_presupuesto([{_numero, texto} | _resto]), do: String.to_integer(texto)

  @doc "Busca en qué {fila, columna} está un símbolo (por ejemplo S o M)."
  def posicion_de(edificio, simbolo) do
    {posicion, _simbolo} = Enum.find(edificio, fn {_posicion, valor} -> valor == simbolo end)
    posicion
  end

  @doc "Junta todo lo que necesita la búsqueda en un solo mapa."
  def construir_datos(registros_terreno, filas_edificio, lineas_bateria) do
    edificio = construir_edificio(filas_edificio)
    [{_numero, primera_fila} | _resto] = filas_edificio

    %{
      terrenos: construir_terrenos(registros_terreno),
      edificio: edificio,
      presupuesto: leer_presupuesto(lineas_bateria),
      inicio: posicion_de(edificio, @simbolo_inicio),
      meta: posicion_de(edificio, @simbolo_meta),
      filas: length(filas_edificio),
      columnas: length(primera_fila)
    }
  end
end
