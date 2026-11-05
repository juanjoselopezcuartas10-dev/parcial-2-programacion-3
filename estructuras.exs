# Problema 1 - Robot de rescate
# Integrantes: [nombre 1], [nombre 2]
#
# Las dos structs del enunciado y los movimientos. Este archivo se carga PRIMERO
# (con Code.require_file), porque para escribir %Terreno{} o %Recorrido{}
# la struct ya debe estar definida.

defmodule Terreno do
  # transitable es true o false (no el texto "si"/"no"), para poder hacer
  # pattern matching: %Terreno{transitable: true, costo: costo}
  defstruct [:simbolo, :nombre, :transitable, :costo]
end

defmodule Recorrido do
  # posiciones: lista de {fila, columna} desde S hasta M
  # energia: energía total consumida
  defstruct [:posiciones, :energia]
end

defmodule Movimiento do
  # Orden FIJO que exige el enunciado: arriba, derecha, abajo, izquierda.
  # Cada par es {cuanto cambia la fila, cuanto cambia la columna}.
  @direcciones [{-1, 0}, {0, 1}, {1, 0}, {0, -1}]

  @doc "Las cuatro casillas vecinas de {fila, columna}, en el orden fijo."
  def vecinos({fila, columna}) do
    Enum.map(@direcciones, fn {cambio_fila, cambio_columna} ->
      {fila + cambio_fila, columna + cambio_columna}
    end)
  end
end
