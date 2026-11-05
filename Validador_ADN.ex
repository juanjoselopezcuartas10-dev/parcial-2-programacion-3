defmodule Validador_ADN do
  @moduledoc """
  Realiza las validaciones de muestras y motivos utilizando recursividad pura.
  """

  @doc "Inicia la validación de las listas de líneas ya filtradas."
  def validar(lineas_muestras, lineas_motivos) do
    {motivos, err_motivos} = validar_motivos(lineas_motivos, [], [], [])
    {muestras, err_muestras} = validar_muestras(lineas_muestras, :esperando_header, [], [], [])

    errores = err_motivos ++ err_muestras

    if errores == [] do
      {:ok, reversa(muestras, []), reversa(motivos, [])}
    else
      {:error, errores}
    end
  end

  # ==========================================
  # VALIDACIÓN DE MOTIVOS
  # ==========================================
  defp validar_motivos([], validos, _vistos, errores), do: {reversa(validos, []), reversa(errores, [])}

  defp validar_motivos([{linea, num_linea} | resto], validos, vistos, errores) do
    motivo = String.upcase(linea)

    cond do
      not solo_adn?(motivo) ->
        err = "Linea #{num_linea}: El motivo '#{motivo}' contiene caracteres invalidos."
        validar_motivos(resto, validos, vistos, [err | errores])

      contiene?(vistos, motivo) ->
        # Ignoramos duplicados conservando el primero (Regla de negocio)
        validar_motivos(resto, validos, vistos, errores)

      true ->
        validar_motivos(resto, [motivo | validos], [motivo | vistos], errores)
    end
  end

  # ==========================================
  # VALIDACIÓN DE MUESTRAS
  # ==========================================
  # Fin de archivo
  defp validar_muestras([], :esperando_header, _, muestras, errores), do: {reversa(muestras, []), reversa(errores, [])}
  
  defp validar_muestras([], {:leyendo, id, sec}, _, muestras, errores) do
    if sec == "" do
      err = "Error al final: La muestra '#{id}' no tiene bases de ADN."
      {reversa(muestras, []), reversa([err | errores], [])}
    else
      {reversa([{id, sec} | muestras], []), reversa(errores, [])}
    end
  end

  # Procesando líneas
  defp validar_muestras([{linea, num_linea} | resto], estado, ids_vistos, muestras, errores) do
    es_header = String.starts_with?(linea, ">")

    case {estado, es_header} do
      {:esperando_header, false} ->
        err = "Linea #{num_linea}: Datos de secuencia antes del primer encabezado."
        validar_muestras(resto, :esperando_header, ids_vistos, muestras, [err | errores])

      {_, true} ->
        id_nuevo = extraer_id(linea)
        
        # Validar si veníamos de leer una muestra anterior
        {muestras_act, errores_act} = 
          case estado do
            {:leyendo, id_ant, sec_ant} when sec_ant == "" ->
              {muestras, ["Linea #{num_linea}: La muestra '#{id_ant}' no tiene bases." | errores]}
            {:leyendo, id_ant, sec_ant} ->
              {[{id_ant, sec_ant} | muestras], errores}
            :esperando_header ->
              {muestras, errores}
          end

        cond do
          id_nuevo == "" ->
            err = "Linea #{num_linea}: Identificador de muestra vacio."
            validar_muestras(resto, {:leyendo, id_nuevo, ""}, ids_vistos, muestras_act, [err | errores_act])
          contiene?(ids_vistos, id_nuevo) ->
            err = "Linea #{num_linea}: El identificador '#{id_nuevo}' esta duplicado."
            validar_muestras(resto, {:leyendo, id_nuevo, ""}, ids_vistos, muestras_act, [err | errores_act])
          true ->
            validar_muestras(resto, {:leyendo, id_nuevo, ""}, [id_nuevo | ids_vistos], muestras_act, errores_act)
        end

      {{:leyendo, id, sec_acc}, false} ->
        seq_upper = String.upcase(linea)
        if solo_adn?(seq_upper) do
          validar_muestras(resto, {:leyendo, id, sec_acc <> seq_upper}, ids_vistos, muestras, errores)
        else
          err = "Linea #{num_linea}: La muestra '#{id}' contiene caracteres invalidos."
          validar_muestras(resto, {:leyendo, id, sec_acc}, ids_vistos, muestras, [err | errores])
        end
    end
  end

  # ==========================================
  # UTILIDADES RECURSIVAS PURAS
  # ==========================================
  defp extraer_id(<<">", resto::binary>>), do: String.trim(resto)
  defp extraer_id(_), do: ""

  defp solo_adn?(<<>>), do: true
  defp solo_adn?(<<c, resto::binary>>) when c in [?A, ?C, ?G, ?T, ?a, ?c, ?g, ?t], do: solo_adn?(resto)
  defp solo_adn?(_), do: false

  defp contiene?([], _elemento), do: false
  defp contiene?([elemento | _resto], elemento), do: true
  defp contiene?([_ | resto], elemento), do: contiene?(resto, elemento)

  defp reversa(lista, acc)
  defp reversa([], acc), do: acc
  defp reversa([h | t], acc), do: reversa(t, [h | acc])
end