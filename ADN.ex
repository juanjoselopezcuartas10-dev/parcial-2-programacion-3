defmodule ADN do
  @moduledoc """
  Controlador principal que orquesta lecturas perezosas, escritura y reportes.
  """

  @archivo_muestras "muestras"
  @archivo_motivos "motivos.txt"
  @archivo_validacion "validacion_adn.txt"
  @archivo_csv "coincidencias_adn.csv"
  @archivo_resumen "resumen_adn.txt"

  @doc "Punto de entrada de la aplicación."
  def ejecutar do
    # Comprobar existencia de archivos (Regla 6)
    if not File.exists?(@archivo_muestras) or not File.exists?(@archivo_motivos) do
      IO.puts(:stderr, "Error: Faltan archivos de entrada, asegurese de tener '#{@archivo_muestras}' y '#{@archivo_motivos}'.")
    else
      # Streams perezosos y filtrado
      stream_muestras = preparar_stream(@archivo_muestras)
      stream_motivos = preparar_stream(@archivo_motivos)

      # Convertir a lista solo para pasarlos a la validación puramente recursiva
      lineas_muestras = Enum.to_list(stream_muestras)
      lineas_motivos = Enum.to_list(stream_motivos)

      case Validador_ADN.validar(lineas_muestras, lineas_motivos) do
        {:error, errores} ->
          reportar_errores_validacion(errores)

        {:ok, muestras, motivos} ->
          IO.puts("Validacion exitosa. Iniciando busqueda...")
          coincidencias = procesar_busqueda(muestras, motivos)
          escribir_csv(coincidencias)
          generar_resumen(coincidencias, muestras, motivos)
      end
    end
  end

  defp preparar_stream(ruta) do
    ruta
    |> File.stream!()
    |> Stream.with_index(1)
    |> Stream.map(fn {linea, idx} -> {String.trim(linea), idx} end)
    |> Stream.reject(fn {linea, _} -> linea == "" or String.starts_with?(linea, "#") end)
  end

  defp reportar_errores_validacion(errores) do
    IO.puts(:stderr, "Se encontraron errores de validacion. Revise '#{@archivo_validacion}'.")
    
    # Escritura progresiva del error log (Regla 4)
    File.open!(@archivo_validacion, [:write, :utf8], fn file ->
      IO.puts(file, "--- REPORTE DE ERRORES DE VALIDACION ---")
      Enum.each(errores, fn err -> IO.puts(file, err) end)
    end)
  end

  defp procesar_busqueda(muestras, motivos) do
    # Búsqueda usando List comprehensions para código limpio y declarativo
    for {id, secuencia} <- muestras,
        motivo <- motivos,
        {muestra, ori, inicio, fin, diffs} <- Buscador_ADN.buscar(id, secuencia, motivo) do
      %{
        muestra: muestra,
        motivo: motivo,
        orientacion: ori,
        inicio: inicio,
        fin: fin,
        diferencias: diffs
      }
    end
  end

  defp escribir_csv(coincidencias) do
    # Ordenar según los requerimientos: muestra, motivo, inicio, orientacion (- antes que +)
    coincidencias_ordenadas = Enum.sort_by(coincidencias, fn c ->
      peso_orientacion = if c.orientacion == "-", do: 0, else: 1
      {c.muestra, c.motivo, c.inicio, peso_orientacion}
    end)

    # Escritura progresiva usando Stream.into hacia File.stream!
    cabecera = ["muestra;motivo;orientacion;inicio;fin;diferencias"]
    
    lineas_datos = 
      Stream.map(coincidencias_ordenadas, fn c ->
        "#{c.muestra};#{c.motivo};#{c.orientacion};#{c.inicio};#{c.fin};#{c.diferencias}"
      end)

    Stream.concat(cabecera, lineas_datos)
    |> Stream.map(&(&1 <> "\n"))
    |> Stream.into(File.stream!(@archivo_csv))
    |> Stream.run()
    
    IO.puts("-> Creado #{@archivo_csv}")
  end

  defp generar_resumen(coincidencias, muestras, motivos) do
    conteo = Enum.frequencies_by(coincidencias, fn c -> {c.muestra, c.motivo} end)
    motivos_encontrados = MapSet.new(coincidencias, & &1.motivo)
    todos_motivos = MapSet.new(motivos)
    motivos_ausentes = MapSet.difference(todos_motivos, motivos_encontrados) |> Enum.to_list()

    File.open!(@archivo_resumen, [:write, :utf8], fn file ->
      IO.puts(file, "=== RESUMEN DE COINCIDENCIAS ===")
      IO.puts("=== RESUMEN DE COINCIDENCIAS ===")
      
      for {id, _sec} <- muestras do
        IO.puts(file, "\nMuestra: #{id}")
        IO.puts("\nMuestra: #{id}")
        
        for motivo <- motivos do
          cantidad = Map.get(conteo, {id, motivo}, 0)
          msg = "  - #{motivo}: #{cantidad} coincidencias"
          IO.puts(file, msg)
          IO.puts(msg)
        end
      end

      msg_ausentes = "\nMotivos que NO aparecieron en ninguna muestra: " <> 
                     if(motivos_ausentes == [], do: "Ninguno (todos aparecieron)", else: Enum.join(motivos_ausentes, ", "))
      
      IO.puts(file, msg_ausentes)
      IO.puts(msg_ausentes)
    end)

    IO.puts("-> Creado #{@archivo_resumen}")
  end
end