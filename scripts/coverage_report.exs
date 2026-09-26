# Mix prunes unused OTP applications from the code path under --no-start.
if :code.which(:cover) == :non_existing do
  [tools_path | _] =
    Path.wildcard(Path.join([List.to_string(:code.root_dir()), "lib", "tools-*", "ebin"]))

  true = Code.prepend_path(tools_path)
end

{:ok, _} = :cover.start()
:ok = :cover.import(~c"cover/current.coverdata")
modules = :cover.imported_modules()

rows =
  Enum.map(modules, fn module ->
    {:ok, lines} = :cover.analyse(module, :coverage, :line)
    # Match Mix's executable-line accounting: ignore generated line 0 and
    # merge duplicate entries, considering a line covered if any entry ran.
    lines =
      Enum.reduce(lines, %{}, fn
        {{_, 0}, _}, acc ->
          acc

        {{_, line}, {covered, missed}}, acc when covered + missed > 0 ->
          Map.update(acc, line, covered > 0, &(&1 or covered > 0))

        _, acc ->
          acc
      end)

    covered = Enum.count(lines, fn {_, ran?} -> ran? end)
    missed = for {line, false} <- lines, do: line
    missed = Enum.sort(missed)
    total = covered + length(missed)

    %{
      module: inspect(module),
      covered: covered,
      total: total,
      missed: missed,
      percent: if(total == 0, do: 100.0, else: Float.round(100 * covered / total, 2))
    }
  end)
  |> Enum.sort_by(&{&1.percent, &1.module})

covered = Enum.sum(Enum.map(rows, & &1.covered))
total = Enum.sum(Enum.map(rows, & &1.total))
percent = Float.round(100 * covered / total, 2)

File.write!(
  "cover/summary.json",
  Jason.encode!(%{covered: covered, total: total, percent: percent, modules: rows}, pretty: true)
)

IO.puts("Coverage: #{percent}% (#{covered}/#{total} executable lines)")
Enum.each(rows, fn r -> IO.puts("#{r.percent}% #{r.module} (#{r.covered}/#{r.total})") end)
