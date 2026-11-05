# Problema 1 - Robot de rescate
# Integrantes: [nombre 1], [nombre 2]
#
# ENUMERACIÓN RECURSIVA CON RETROCESO de todos los recorridos simples de S a M
# cuya energía no supera B. Devuelve un Stream PEREZOSO de %Recorrido{}:
# no arma la lista de todos los recorridos; cada uno se produce cuando alguien lo pide.
#
# Retroceso: "visitadas" y "camino" son datos inmutables que se pasan hacia abajo.
# Al volver de una rama, esos datos siguen siendo los de antes de entrar: "desmarcar"
# ocurre solo, sin código extra.

defmodule RescateBusqueda do
  # ---------- El "qué" ----------

  @doc "Stream perezoso de todos los %Recorrido{} válidos, en el orden arriba, derecha, abajo, izquierda."
  def recorridos(datos) do
    explorar(datos.inicio, MapSet.new([datos.inicio]), 0, [datos.inicio], datos)
  end

  # ---------- El "cómo" ----------

  # Caso base: se llegó a la meta. Se emite UN recorrido (el camino está al revés, se invierte).
  defp explorar(posicion, _visitadas, energia, camino, %{meta: meta} = _datos)
       when posicion == meta do
    [%Recorrido{posiciones: invertir(camino), energia: energia}]
  end

  # Caso recursivo: se prueba cada vecino (en orden fijo) y se juntan los resultados.
  # Stream.flat_map es perezoso: no explora el vecino siguiente hasta que se necesita.
  defp explorar(posicion, visitadas, energia, camino, datos) do
    posicion
    |> Movimiento.vecinos()
    |> Stream.flat_map(fn vecino -> avanzar(vecino, visitadas, energia, camino, datos) end)
  end

  # No se repite casilla: si ya está en el camino, esta rama no produce nada ([])
  defp avanzar(vecino, visitadas, energia, camino, datos) do
    if MapSet.member?(visitadas, vecino) do
      []
    else
      entrar(vecino, visitadas, energia, camino, datos)
    end
  end

  # Pattern matching sobre la struct + guarda con el presupuesto.
  # Solo se entra si el terreno existe, es transitable y la energía no supera B.
  defp entrar(vecino, visitadas, energia, camino, datos) do
    case terreno_en(vecino, datos) do
      %Terreno{transitable: true, costo: costo} when energia + costo <= datos.presupuesto ->
        explorar(vecino, MapSet.put(visitadas, vecino), energia + costo, [vecino | camino], datos)

      _otro ->
        []   # fuera del mapa, pared, o se pasaría del presupuesto
    end
  end

  # nil si la posición no existe en el edificio (o el símbolo no tiene terreno)
  defp terreno_en(posicion, datos) do
    simbolo = Map.get(datos.edificio, posicion)
    Map.get(datos.terrenos, simbolo)
  end

  # Invertir recursivo (el camino se arma con [vecino | camino], o sea al revés)
  defp invertir(lista), do: invertir(lista, [])
  defp invertir([], acumulado), do: acumulado
  defp invertir([head | tail], acumulado), do: invertir(tail, [head | acumulado])
end
