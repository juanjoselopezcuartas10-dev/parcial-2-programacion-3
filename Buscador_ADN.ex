defmodule Buscador_ADN do
  @moduledoc """
  Implementa la reversa complementaria y la búsqueda por ventanas iterativas.
  """

  @doc "Calcula la reversa complementaria usando recursión binaria."
  def reversa_complementaria(secuencia) do
    _reversa_complementaria(secuencia, <<>>)
  end

  defp _reversa_complementaria(<<>>, acc), do: acc
  defp _reversa_complementaria(<<?A, resto::binary>>, acc), do: _reversa_complementaria(resto, <<?T, acc::binary>>)
  defp _reversa_complementaria(<<?C, resto::binary>>, acc), do: _reversa_complementaria(resto, <<?G, acc::binary>>)
  defp _reversa_complementaria(<<?G, resto::binary>>, acc), do: _reversa_complementaria(resto, <<?C, acc::binary>>)
  defp _reversa_complementaria(<<?T, resto::binary>>, acc), do: _reversa_complementaria(resto, <<?A, acc::binary>>)

  @doc "Cuenta las diferencias entre dos cadenas del mismo tamaño."
  def contar_diferencias(s1, s2), do: _contar_diferencias(s1, s2, 0)

  defp _contar_diferencias(<<>>, <<>>, diffs), do: diffs
  defp _contar_diferencias(<<c, r1::binary>>, <<c, r2::binary>>, diffs), do: _contar_diferencias(r1, r2, diffs)
  defp _contar_diferencias(<<_, r1::binary>>, <<_, r2::binary>>, diffs), do: _contar_diferencias(r1, r2, diffs + 1)

  @doc "Busca un motivo en una secuencia, explorando + y -."
  def buscar(id_muestra, secuencia, motivo) do
    len_secuencia = byte_size(secuencia)
    len_motivo = byte_size(motivo)

    if len_motivo > len_secuencia do
      [] # Regla: descartar sin comparar si motivo > muestra
    else
      max_pos = len_secuencia - len_motivo
      motivo_rev = reversa_complementaria(motivo)

      # Buscamos en ambas direcciones. Si es palíndromo, arrojará doble resultado como se pide.
      resultados_positivos = buscar_ventanas(id_muestra, secuencia, motivo, len_motivo, "+", 0, max_pos, [])
      resultados_negativos = buscar_ventanas(id_muestra, secuencia, motivo_rev, len_motivo, "-", 0, max_pos, [])

      resultados_positivos ++ resultados_negativos
    end
  end

  defp buscar_ventanas(_id, _secuencia, _motivo, _len, _ori, pos, max_pos, acc) when pos > max_pos do
    reversa(acc, [])
  end

  defp buscar_ventanas(id, secuencia, motivo, len_motivo, ori, pos, max_pos, acc) do
    ventana = binary_part(secuencia, pos, len_motivo)
    diferencias = contar_diferencias(ventana, motivo)

    nuevo_acc =
      if diferencias <= 1 do
        # Generar coincidencia: {muestra, motivo_original, orientacion, inicio, fin, diferencias}
        fin = pos + len_motivo - 1
        [{id, ori, pos, fin, diferencias} | acc]
      else
        acc
      end

    buscar_ventanas(id, secuencia, motivo, len_motivo, ori, pos + 1, max_pos, nuevo_acc)
  end

  defp reversa([], acc), do: acc
  defp reversa([h | t], acc), do: reversa(t, [h | acc])
end