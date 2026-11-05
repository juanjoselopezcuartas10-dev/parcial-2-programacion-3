# Problema 1 - Robot de rescate
# Integrantes: [nombre 1], [nombre 2]
#
# STREAM INFINITO de relajación de energía mínima.
# Un "estado" es un mapa %{{fila, columna} => costo_minimo_conocido}.
#   Paso 0: solo S tiene costo 0.
#   Cada paso: se conservan los costos y cada casilla transitable se actualiza
#   a partir de sus vecinos (costo del vecino + costo de ENTRAR a esa casilla),
#   descartando lo que supere B.
# El flujo no tiene fin, pero llega un momento en que un paso ya no cambia nada.

defmodule RescateRelajacion do
  # ---------- El "qué" ----------

  @doc """
  Consume el Stream hasta el primer par de estados consecutivos iguales.
  Devuelve %{estados: pasos distintos, indice: índice de estabilización, estado_final: ...}
  """
  def relajar(datos) do
    flujo = flujo_de_estados(datos)
    indice = indice_de_estabilizacion(flujo)
    estados = Enum.take(flujo, indice + 1)

    %{estados: estados, indice: indice, estado_final: List.last(estados)}
  end

  # ---------- El "cómo" ----------

  # Stream INFINITO: estado0, paso(estado0), paso(paso(estado0)), ...
  # (como los primos con Stream.iterate; no calcula nada hasta que alguien lo consuma)
  def flujo_de_estados(datos) do
    estado_inicial = %{datos.inicio => 0}
    Stream.iterate(estado_inicial, fn estado -> siguiente_estado(estado, datos) end)
  end

  # Numera los estados (0, 1, 2...), los agrupa de a pares consecutivos
  # [{estado0, 0}, {estado1, 1}], [{estado1, 1}, {estado2, 2}], ...
  # y se queda con el primer par cuyos dos estados son iguales.
  # El índice de estabilización es el del PRIMER estado de ese par.
  defp indice_de_estabilizacion(flujo) do
    [{_estado, indice}, _siguiente] =
      flujo
      |> Stream.with_index()
      |> Stream.chunk_every(2, 1, :discard)
      |> Enum.find(fn [{estado_a, _}, {estado_b, _}] -> estado_a == estado_b end)

    indice
  end

  # Un paso: se recorre TODO el edificio, leyendo SIEMPRE del estado anterior
  # (por eso "estado" no cambia durante el reduce; lo que se va llenando es "nuevo")
  defp siguiente_estado(estado, datos) do
    Enum.reduce(datos.edificio, estado, fn {posicion, simbolo}, nuevo ->
      actualizar(nuevo, estado, posicion, simbolo, datos)
    end)
  end

  # Pattern matching sobre la struct: solo las casillas transitables se actualizan
  defp actualizar(nuevo, estado, posicion, simbolo, datos) do
    case Map.get(datos.terrenos, simbolo) do
      %Terreno{transitable: true, costo: costo} ->
        mejorar(nuevo, estado, posicion, costo, datos.presupuesto)

      _no_transitable ->
        nuevo
    end
  end

  # Candidato = el mejor costo entre los vecinos que ya tienen costo + costo de entrar aquí
  defp mejorar(nuevo, estado, posicion, costo, presupuesto) do
    case mejor_candidato(estado, posicion, costo) do
      nil -> nuevo
      candidato when candidato > presupuesto -> nuevo
      candidato -> Map.update(nuevo, posicion, candidato, fn actual -> min(actual, candidato) end)
    end
  end

  defp mejor_candidato(estado, posicion, costo) do
    posicion
    |> Movimiento.vecinos()
    |> Enum.flat_map(fn vecino -> costo_con_entrada(estado, vecino, costo) end)
    |> Enum.min(fn -> nil end)
  end

  # Si el vecino ya tiene costo conocido: [su costo + costo de entrar]; si no: []
  defp costo_con_entrada(estado, vecino, costo) do
    case Map.fetch(estado, vecino) do
      {:ok, costo_vecino} -> [costo_vecino + costo]
      :error -> []
    end
  end
end
