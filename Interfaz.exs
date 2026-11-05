defmodule Adn_Interfaz do
  @moduledoc """
  Interfaz del sistema de análisis de ADN.
  """

  @doc "Inicia el bucle principal del menú."
  def iniciar do
    cargar_dependencias()
    mostrar_opciones()
  end

  defp cargar_dependencias do
    # Compila y carga los módulos en memoria automáticamente
    Code.require_file("Validador_ADN.ex")
    Code.require_file("Buscador_ADN.ex")
    Code.require_file("ADN.ex")
  end

  defp mostrar_opciones do
    IO.puts("\n========================================")
    IO.puts("    SISTEMA DE ANÁLISIS DE ADN")
    IO.puts("========================================")
    IO.puts("1. Ejecutar búsqueda de motivos")
    IO.puts("2. Salir")
    IO.puts("========================================")

    opcion = 
      IO.gets("Seleccione una opción (1 o 2): ") 
      |> String.trim()

    procesar_seleccion(opcion)
  end

  defp procesar_seleccion("1") do
    IO.puts("\n>>> Iniciando el procesamiento...\n")
    
    # Capturamos posibles caídas para que el menú no se cierre bruscamente
    try do
      ADN.ejecutar()
    rescue
      e -> IO.puts(:stderr, "\nError inesperado: #{inspect(e)}")
    end

    IO.gets("\nProceso finalizado. Presione ENTER para volver al menú...")
    mostrar_opciones()
  end

  defp procesar_seleccion("2") do
    IO.puts("\nSaliendo del programa. ¡Hasta pronto!\n")
    System.halt(0)
  end

  defp procesar_seleccion(_opcion_invalida) do
    IO.puts("\n[!] Opción no válida. Por favor, intente de nuevo.")
    mostrar_opciones()
  end
end

# Punto de ejecución automático al correr el script
Adn_Interfaz.iniciar()