# Problema 1 - Robot de rescate
# Integrantes: [nombre 1], [nombre 2]
#
# VALIDACIÓN PREVIA con recursión propia.
# Regla del enunciado: aquí adentro NO se llama a Enum ni a Stream.
# (Sí se usan String.*, Integer.parse, length/1 y ++, que no son Enum ni Stream.)
#
# Todas las funciones devuelven una lista de errores {ubicacion, mensaje}.
# Lista vacía = todo bien. No se detienen en el primer error: juntan TODOS.
# Entradas (ya leídas, como listas):
#   registros de terrenos:  [{numero_linea, [simbolo, nombre, transitable, costo]}, ...]
#   filas del edificio:     [{numero_linea, [simbolo, simbolo, ...]}, ...]
#   líneas de batería:      [{numero_linea, texto}, ...]

defmodule RescateValidacion do
  @simbolo_inicio "S"
  @simbolo_meta "M"
  @simbolo_borde "X"

  # ---------- El "qué" ----------

  @doc "Valida los tres archivos y devuelve todos los errores juntos."
  def validar(registros_terreno, filas_edificio, lineas_bateria) do
    definidos = simbolos_definidos(registros_terreno)

    validar_terrenos(registros_terreno, []) ++
      validar_edificio(filas_edificio, definidos) ++
      validar_bateria(lineas_bateria)
  end

  # ---------- terrenos.csv ----------

  # Lista de los símbolos que terrenos.csv define (forma de filtrar_mayores)
  defp simbolos_definidos([]), do: []

  defp simbolos_definidos([{_numero, [simbolo | _otros]} | resto]) when simbolo != "" do
    [simbolo | simbolos_definidos(resto)]
  end

  defp simbolos_definidos([_registro | resto]), do: simbolos_definidos(resto)

  # vistos = símbolos de los registros anteriores (para detectar repetidos)
  defp validar_terrenos([], _vistos), do: []   # Caso base

  defp validar_terrenos([{numero, campos} | resto], vistos) do   # Caso recursivo
    errores_del_registro = errores_registro(numero, campos, vistos)
    [simbolo | _otros] = campos
    errores_del_registro ++ validar_terrenos(resto, [simbolo | vistos])
  end

  defp errores_registro(numero, [simbolo, _nombre, transitable, costo], vistos) do
    ubicacion = "terrenos.csv línea #{numero}"

    error_simbolo(simbolo, vistos, ubicacion) ++
      error_transitable(transitable, ubicacion) ++
      error_costo(costo, transitable, simbolo, ubicacion)
  end

  defp errores_registro(numero, campos, _vistos) do
    [{"terrenos.csv línea #{numero}", "se esperaban 4 campos y hay #{length(campos)}"}]
  end

  defp error_simbolo("", _vistos, ubicacion), do: [{ubicacion, "el símbolo está vacío"}]

  defp error_simbolo(simbolo, vistos, ubicacion) do
    if contiene?(vistos, simbolo) do
      [{ubicacion, "el símbolo '#{simbolo}' está repetido"}]
    else
      []
    end
  end

  defp error_transitable("si", _ubicacion), do: []
  defp error_transitable("no", _ubicacion), do: []

  defp error_transitable(texto, ubicacion) do
    [{ubicacion, "transitable debe ser 'si' o 'no' y se leyó '#{texto}'"}]
  end

  # Integer.parse devuelve {numero, resto} o :error; solo se acepta si resto == ""
  defp error_costo(texto, transitable, simbolo, ubicacion) do
    case Integer.parse(texto) do
      {valor, ""} when valor < 0 ->
        [{ubicacion, "el costo debe ser un entero no negativo y se leyó #{valor}"}]

      {0, ""} when transitable == "si" and simbolo != @simbolo_inicio ->
        [{ubicacion, "una casilla transitable distinta de S debe tener costo positivo"}]

      {_valor, ""} ->
        []

      _otro ->
        [{ubicacion, "el costo debe ser un entero y se leyó '#{texto}'"}]
    end
  end

  # ---------- edificio.txt ----------

  defp validar_edificio([], _definidos) do
    [{"edificio.txt", "el edificio está vacío"}]
  end

  defp validar_edificio([{_numero, primera_fila} | _resto] = filas, definidos) do
    ancho = length(primera_fila)
    ultima_fila = length(filas) - 1

    errores_rectangular(filas, ancho) ++
      errores_simbolos(filas, 0, definidos) ++
      errores_rol(filas, @simbolo_inicio) ++
      errores_rol(filas, @simbolo_meta) ++
      errores_borde(filas, 0, ultima_fila)
  end

  # --- rectangular: todas las filas con el mismo ancho que la primera ---
  defp errores_rectangular([], _ancho), do: []

  defp errores_rectangular([{numero, simbolos} | resto], ancho) do
    errores_de_esta_fila =
      if length(simbolos) == ancho do
        []
      else
        [{"edificio.txt línea #{numero}",
          "la fila tiene #{length(simbolos)} columnas y se esperaban #{ancho}"}]
      end

    errores_de_esta_fila ++ errores_rectangular(resto, ancho)
  end

  # --- símbolos definidos: recorre filas y, dentro de cada fila, columnas ---
  defp errores_simbolos([], _fila, _definidos), do: []

  defp errores_simbolos([{numero, simbolos} | resto], fila, definidos) do
    errores_celdas(simbolos, numero, fila, 0, definidos) ++
      errores_simbolos(resto, fila + 1, definidos)
  end

  defp errores_celdas([], _numero, _fila, _columna, _definidos), do: []

  defp errores_celdas([simbolo | resto], numero, fila, columna, definidos) do
    errores_de_esta_celda =
      if contiene?(definidos, simbolo) do
        []
      else
        [{"edificio.txt línea #{numero}, posición (#{fila}, #{columna})",
          "el símbolo '#{simbolo}' no está definido en terrenos.csv"}]
      end

    errores_de_esta_celda ++ errores_celdas(resto, numero, fila, columna + 1, definidos)
  end

  # --- exactamente un S y exactamente una M ---
  defp errores_rol(filas, simbolo) do
    case posiciones_de(filas, simbolo, 0) do
      [] -> [{"edificio.txt", "no hay ningún '#{simbolo}' en el edificio"}]
      [_primera | repetidas] -> errores_repetidos(repetidas, simbolo)
    end
  end

  defp errores_repetidos([], _simbolo), do: []

  defp errores_repetidos([{numero, fila, columna} | resto], simbolo) do
    [{"edificio.txt línea #{numero}, posición (#{fila}, #{columna})",
      "'#{simbolo}' repetido: debe haber exactamente uno"}] ++
      errores_repetidos(resto, simbolo)
  end

  # Lista de {numero_linea, fila, columna} donde aparece el símbolo
  defp posiciones_de([], _simbolo, _fila), do: []

  defp posiciones_de([{numero, simbolos} | resto], simbolo, fila) do
    posiciones_en_fila(simbolos, simbolo, numero, fila, 0) ++
      posiciones_de(resto, simbolo, fila + 1)
  end

  defp posiciones_en_fila([], _simbolo, _numero, _fila, _columna), do: []

  defp posiciones_en_fila([simbolo | resto], simbolo, numero, fila, columna) do
    [{numero, fila, columna} | posiciones_en_fila(resto, simbolo, numero, fila, columna + 1)]
  end

  defp posiciones_en_fila([_otro | resto], simbolo, numero, fila, columna) do
    posiciones_en_fila(resto, simbolo, numero, fila, columna + 1)
  end

  # --- borde: primera y última fila completas en X; las demás, solo sus extremos ---
  defp errores_borde([], _fila, _ultima_fila), do: []

  defp errores_borde([{numero, simbolos} | resto], fila, ultima_fila)
       when fila == 0 or fila == ultima_fila do
    errores_fila_completa(simbolos, numero, fila, 0) ++
      errores_borde(resto, fila + 1, ultima_fila)
  end

  defp errores_borde([{numero, simbolos} | resto], fila, ultima_fila) do
    errores_extremos(simbolos, numero, fila) ++ errores_borde(resto, fila + 1, ultima_fila)
  end

  defp errores_fila_completa([], _numero, _fila, _columna), do: []

  defp errores_fila_completa([simbolo | resto], numero, fila, columna) do
    error_borde(simbolo, numero, fila, columna) ++
      errores_fila_completa(resto, numero, fila, columna + 1)
  end

  defp errores_extremos([primero | _resto] = simbolos, numero, fila) do
    {ultimo, columna_ultimo} = ultimo_con_columna(simbolos, 0)

    if columna_ultimo == 0 do
      error_borde(primero, numero, fila, 0)
    else
      error_borde(primero, numero, fila, 0) ++ error_borde(ultimo, numero, fila, columna_ultimo)
    end
  end

  # Último elemento de la lista y su posición (columna)
  defp ultimo_con_columna([unico], columna), do: {unico, columna}   # Caso base
  defp ultimo_con_columna([_head | tail], columna), do: ultimo_con_columna(tail, columna + 1)

  defp error_borde(@simbolo_borde, _numero, _fila, _columna), do: []

  defp error_borde(simbolo, numero, fila, columna) do
    [{"edificio.txt línea #{numero}, posición (#{fila}, #{columna})",
      "el borde debe ser '#{@simbolo_borde}' y hay '#{simbolo}'"}]
  end

  # ---------- bateria.txt ----------

  defp validar_bateria([]) do
    [{"bateria.txt", "no contiene ningún valor de B"}]
  end

  defp validar_bateria([{numero, texto} | sobrantes]) do
    errores_valor(numero, texto) ++ errores_sobrantes(sobrantes)
  end

  defp errores_valor(numero, texto) do
    case Integer.parse(texto) do
      {valor, ""} when valor > 0 -> []
      _otro -> [{"bateria.txt línea #{numero}", "B debe ser un entero positivo y se leyó '#{texto}'"}]
    end
  end

  # B debe ser UN ÚNICO valor: cada línea de datos adicional es un error
  defp errores_sobrantes([]), do: []

  defp errores_sobrantes([{numero, _texto} | resto]) do
    [{"bateria.txt línea #{numero}", "sobra esta línea: B debe ser un único valor"}] ++
      errores_sobrantes(resto)
  end

  # ---------- Utilidad ----------

  # ¿La lista contiene el elemento? (el mismo nombre dos veces en la cabeza = "son iguales")
  defp contiene?([], _buscado), do: false
  defp contiene?([buscado | _resto], buscado), do: true
  defp contiene?([_otro | resto], buscado), do: contiene?(resto, buscado)
end
