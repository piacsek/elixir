Code.require_file("../test_helper.exs", __DIR__)

defmodule IEx.AutocompleteTest do
  use ExUnit.Case, async: true

  setup do
    evaluator = IEx.Server.start_evaluator([])
    Process.put(:evaluator, evaluator)
    :ok
  end

  defp eval(line) do
    ExUnit.CaptureIO.capture_io(fn ->
      evaluator = Process.get(:evaluator)
      Process.group_leader(evaluator, Process.group_leader())
      send(evaluator, {:eval, self(), line <> "\n", %IEx.State{}})
      assert_receive {:evaled, _, _, _}
    end)
  end

  defp expand(expr) do
    IEx.Autocomplete.expand(Enum.reverse(expr), self())
  end

  test "Erlang module completion" do
    assert expand(':zl') == {:yes, 'ib', []}
  end

  test "Erlang module no completion" do
    assert expand(':unknown') == {:no, '', []}
  end

  test "Erlang module multiple values completion" do
    {:yes, '', list} = expand(':user')
    assert 'user' in list
    assert 'user_drv' in list
  end

  test "Erlang root completion" do
    {:yes, '', list} = expand(':')
    assert is_list(list)
    assert 'lists' in list
  end

  test "Elixir proxy" do
    {:yes, '', list} = expand('E')
    assert 'Elixir' in list
  end

  test "Elixir completion" do
    assert expand('En') == {:yes, 'um', []}
    assert expand('Enumera') == {:yes, 'ble', []}
  end

  test "Elixir type completion" do
    assert expand('t :gen_ser') == {:yes, 'ver', []}
    assert expand('t String') == {:yes, '', ['String', 'StringIO']}
    assert expand('t String.') == {:yes, '', ['codepoint/0', 'grapheme/0', 'pattern/0', 't/0']}
    assert expand('t String.grap') == {:yes, 'heme', []}
    assert expand('t  String.grap') == {:yes, 'heme', []}
    assert {:yes, '', ['date_time/0' | _]} = expand('t :file.')
    assert expand('t :file.n') == {:yes, 'ame', []}
  end

  test "Elixir callback completion" do
    assert expand('b :strin') == {:yes, 'g', []}
    assert expand('b String') == {:yes, '', ['String', 'StringIO']}
    assert expand('b String.') == {:no, '', []}
    assert expand('b Access.') == {:yes, '', ['fetch/2', 'get_and_update/3', 'pop/2']}
    assert expand('b GenServer.term') == {:yes, 'inate', []}
    assert expand('b   GenServer.term') == {:yes, 'inate', []}
    assert expand('b :gen_server.handle_in') == {:yes, 'fo', []}
  end

  test "Elixir helper completion with parentheses" do
    assert expand('t(:gen_ser') == {:yes, 'ver', []}
    assert expand('t(String') == {:yes, '', ['String', 'StringIO']}
    assert expand('t(String.') == {:yes, '', ['codepoint/0', 'grapheme/0', 'pattern/0', 't/0']}
    assert expand('t(String.grap') == {:yes, 'heme', []}
  end

  test "Elixir completion with self" do
    assert expand('Enumerable') == {:yes, '.', []}
  end

  test "Elixir completion on modules from load path" do
    assert expand('Str') == {:yes, [], ['Stream', 'String', 'StringIO']}
    assert expand('Ma') == {:yes, '', ['Macro', 'Map', 'MapSet', 'MatchError']}
    assert expand('Dic') == {:yes, 't', []}
    assert expand('Ex') == {:yes, [], ['ExUnit', 'Exception']}
  end

  test "Elixir no completion for underscored functions with no doc" do
    {:module, _, bytecode, _} =
      defmodule Elixir.Sample do
        def __foo__(), do: 0
        @doc "Bar doc"
        def __bar__(), do: 1
      end

    File.write!("Elixir.Sample.beam", bytecode)
    assert {:docs_v1, _, _, _, _, _, _} = Code.fetch_docs(Sample)
    assert expand('Sample._') == {:yes, '_bar__', []}
  after
    File.rm("Elixir.Sample.beam")
    :code.purge(Sample)
    :code.delete(Sample)
  end

  test "Elixir no completion for default argument functions with doc set to false" do
    {:yes, '', available} = expand('String.')
    refute Enum.member?(available, 'rjust/2')
    assert Enum.member?(available, 'replace/3')

    assert expand('String.r') == {:yes, 'e', []}

    {:module, _, bytecode, _} =
      defmodule Elixir.DefaultArgumentFunctions do
        def foo(a \\ :a, b, c \\ :c), do: {a, b, c}

        def _do_fizz(a \\ :a, b, c \\ :c), do: {a, b, c}

        @doc false
        def __fizz__(a \\ :a, b, c \\ :c), do: {a, b, c}

        @doc "bar/0 doc"
        def bar(), do: :bar
        @doc false
        def bar(a \\ :a, b, c \\ :c, d \\ :d), do: {a, b, c, d}
        @doc false
        def bar(a, b, c, d, e), do: {a, b, c, d, e}

        @doc false
        def baz(a \\ :a), do: {a}

        @doc "biz/3 doc"
        def biz(a, b, c \\ :c), do: {a, b, c}
      end

    File.write!("Elixir.DefaultArgumentFunctions.beam", bytecode)
    assert {:docs_v1, _, _, _, _, _, _} = Code.fetch_docs(DefaultArgumentFunctions)

    functions_list = ['bar/0', 'biz/2', 'biz/3', 'foo/1', 'foo/2', 'foo/3']
    assert expand('DefaultArgumentFunctions.') == {:yes, '', functions_list}

    assert expand('DefaultArgumentFunctions.bi') == {:yes, 'z', []}
    assert expand('DefaultArgumentFunctions.foo') == {:yes, '', ['foo/1', 'foo/2', 'foo/3']}
  after
    File.rm("Elixir.DefaultArgumentFunctions.beam")
    :code.purge(DefaultArgumentFunctions)
    :code.delete(DefaultArgumentFunctions)
  end

  test "Elixir no completion" do
    assert expand('.') == {:no, '', []}
    assert expand('Xyz') == {:no, '', []}
    assert expand('x.Foo') == {:no, '', []}
    assert expand('x.Foo.get_by') == {:no, '', []}
    assert expand('@foo.bar') == {:no, '', []}
  end

  test "Elixir root submodule completion" do
    assert expand('Elixir.Acce') == {:yes, 'ss', []}
  end

  test "Elixir submodule completion" do
    assert expand('String.Cha') == {:yes, 'rs', []}
  end

  test "Elixir submodule no completion" do
    assert expand('IEx.Xyz') == {:no, '', []}
  end

  test "function completion" do
    assert expand('System.ve') == {:yes, 'rsion', []}
    assert expand(':ets.fun2') == {:yes, 'ms', []}
  end

  test "function completion with arity" do
    assert expand('String.printable?') == {:yes, '', ['printable?/1', 'printable?/2']}
    assert expand('String.printable?/') == {:yes, '', ['printable?/1', 'printable?/2']}

    assert expand('Enum.count') ==
             {:yes, '', ['count/1', 'count/2', 'count_until/2', 'count_until/3']}

    assert expand('Enum.count/') == {:yes, '', ['count/1', 'count/2']}
  end

  test "operator completion" do
    assert expand('+') == {:yes, '', ['+/1', '+/2', '++/2']}
    assert expand('+/') == {:yes, '', ['+/1', '+/2']}
    assert expand('++/') == {:yes, '', ['++/2']}
  end

  test "sigil completion" do
    {:yes, '', sigils} = expand('~')
    assert '~C (sigil_C)' in sigils
    {:yes, '', sigils} = expand('~r')
    assert '"' in sigils
    assert '(' in sigils

    eval("import Bitwise")
    {:yes, '', sigils} = expand('~')
    assert '~~~/1' in sigils

    assert expand('~~') == {:yes, '~', []}
    assert expand('~~~') == {:yes, '', ['~~~/1']}
  end

  test "function completion using a variable bound to a module" do
    eval("mod = String")
    assert expand('mod.print') == {:yes, 'able?', []}
  end

  test "map atom key completion is supported" do
    eval("map = %{foo: 1, bar_1: 23, bar_2: 14}")
    assert expand('map.f') == {:yes, 'oo', []}
    assert expand('map.b') == {:yes, 'ar_', []}
    assert expand('map.bar_') == {:yes, '', ['bar_1', 'bar_2']}
    assert expand('map.c') == {:no, '', []}
    assert expand('map.') == {:yes, '', ['bar_1', 'bar_2', 'foo']}
    assert expand('map.foo') == {:no, '', []}
  end

  test "nested map atom key completion is supported" do
    eval("map = %{nested: %{deeply: %{foo: 1, bar_1: 23, bar_2: 14, mod: String, num: 1}}}")
    assert expand('map.nested.deeply.f') == {:yes, 'oo', []}
    assert expand('map.nested.deeply.b') == {:yes, 'ar_', []}
    assert expand('map.nested.deeply.bar_') == {:yes, '', ['bar_1', 'bar_2']}
    assert expand('map.nested.deeply.') == {:yes, '', ['bar_1', 'bar_2', 'foo', 'mod', 'num']}
    assert expand('map.nested.deeply.mod.print') == {:yes, 'able?', []}

    assert expand('map.nested') == {:yes, '.', []}
    assert expand('map.nested.deeply') == {:yes, '.', []}
    assert expand('map.nested.deeply.foo') == {:no, '', []}

    assert expand('map.nested.deeply.c') == {:no, '', []}
    assert expand('map.a.b.c.f') == {:no, '', []}
  end

  test "map string key completion is not supported" do
    eval(~S(map = %{"foo" => 1}))
    assert expand('map.f') == {:no, '', []}
  end

  test "bound variables for modules and maps" do
    eval("num = 5; map = %{nested: %{num: 23}}")
    assert expand('num.print') == {:no, '', []}
    assert expand('map.nested.num.f') == {:no, '', []}
    assert expand('map.nested.num.key.f') == {:no, '', []}
  end

  test "access syntax is not supported" do
    eval("map = %{nested: %{deeply: %{num: 23}}}")
    assert expand('map[:nested][:deeply].n') == {:no, '', []}
    assert expand('map[:nested].deeply.n') == {:no, '', []}
    assert expand('map.nested.[:deeply].n') == {:no, '', []}
  end

  test "unbound variables is not supported" do
    eval("num = 5")
    assert expand('other_var.f') == {:no, '', []}
    assert expand('a.b.c.d') == {:no, '', []}
  end

  test "macro completion" do
    {:yes, '', list} = expand('Kernel.is_')
    assert is_list(list)
  end

  test "imports completion" do
    {:yes, '', list} = expand('')
    assert is_list(list)
    assert 'h/1' in list
    assert 'unquote/1' in list
    assert 'pwd/0' in list
  end

  test "kernel import completion" do
    assert expand('defstru') == {:yes, 'ct', []}
    assert expand('put_') == {:yes, '', ['put_elem/3', 'put_in/2', 'put_in/3']}
  end

  test "variable name completion" do
    eval("numeral = 3; number = 3; nothing = nil")
    assert expand('numb') == {:yes, 'er', []}
    assert expand('num') == {:yes, '', ['number', 'numeral']}
    assert expand('no') == {:yes, '', ['nothing', 'node/0', 'node/1', 'not/1']}
  end

  test "completion of manually imported functions and macros" do
    eval("import Enum; import Supervisor, only: [count_children: 1]; import Protocol")

    assert expand('der') == {:yes, 'ive', []}

    assert expand('take') ==
             {:yes, '', ['take/2', 'take_every/2', 'take_random/2', 'take_while/2']}

    assert expand('take/') == {:yes, '', ['take/2']}

    assert expand('count') ==
             {:yes, '',
              ['count/1', 'count/2', 'count_children/1', 'count_until/2', 'count_until/3']}

    assert expand('count/') == {:yes, '', ['count/1', 'count/2']}
  end

  defmacro define_var do
    quote(do: var!(my_var_1, Elixir) = 1)
  end

  test "ignores quoted variables when performing variable completion" do
    eval("require #{__MODULE__}; #{__MODULE__}.define_var(); my_var_2 = 2")
    assert expand('my_var') == {:yes, '_2', []}
  end

  test "kernel special form completion" do
    assert expand('unquote_spl') == {:yes, 'icing', []}
  end

  test "completion inside expression" do
    assert expand('1 En') == {:yes, 'um', []}
    assert expand('Test(En') == {:yes, 'um', []}
    assert expand('Test :zl') == {:yes, 'ib', []}
    assert expand('[:zl') == {:yes, 'ib', []}
    assert expand('{:zl') == {:yes, 'ib', []}
  end

  defmodule SublevelTest.LevelA.LevelB do
  end

  test "Elixir completion sublevel" do
    assert expand('IEx.AutocompleteTest.SublevelTest.') == {:yes, 'LevelA', []}
  end

  test "complete aliases of Elixir modules" do
    eval("alias List, as: MyList")
    assert expand('MyL') == {:yes, 'ist', []}
    assert expand('MyList') == {:yes, '.', []}
    assert expand('MyList.to_integer') == {:yes, [], ['to_integer/1', 'to_integer/2']}
  end

  test "complete aliases of Erlang modules" do
    eval("alias :lists, as: EList")
    assert expand('EL') == {:yes, 'ist', []}
    assert expand('EList') == {:yes, '.', []}
    assert expand('EList.map') == {:yes, [], ['map/2', 'mapfoldl/3', 'mapfoldr/3']}
  end

  test "completion for functions added when compiled module is reloaded" do
    {:module, _, bytecode, _} =
      defmodule Sample do
        def foo(), do: 0
      end

    File.write!("Elixir.IEx.AutocompleteTest.Sample.beam", bytecode)
    assert {:docs_v1, _, _, _, _, _, _} = Code.fetch_docs(Sample)
    assert expand('IEx.AutocompleteTest.Sample.foo') == {:yes, '', ['foo/0']}

    Code.compiler_options(ignore_module_conflict: true)

    defmodule Sample do
      def foo(), do: 0
      def foobar(), do: 0
    end

    assert expand('IEx.AutocompleteTest.Sample.foo') == {:yes, '', ['foo/0', 'foobar/0']}
  after
    File.rm("Elixir.IEx.AutocompleteTest.Sample.beam")
    Code.compiler_options(ignore_module_conflict: false)
    :code.purge(Sample)
    :code.delete(Sample)
  end

  defmodule MyStruct do
    defstruct [:my_val]
  end

  test "completion for struct names" do
    assert {:yes, '', entries} = expand('%')
    assert 'URI' in entries
    assert 'IEx.History' in entries
    assert 'IEx.State' in entries

    assert {:yes, '', entries} = expand('%IEx.')
    assert 'IEx.History' in entries
    assert 'IEx.State' in entries

    assert expand('%IEx.AutocompleteTe') == {:yes, 'st.MyStruct{', []}
    assert expand('%IEx.AutocompleteTest.MyStr') == {:yes, 'uct{', []}

    eval("alias IEx.AutocompleteTest.MyStruct")
    assert expand('%MyStr') == {:yes, 'uct{', []}
  end

  test "completion for struct keys" do
    assert {:yes, '', entries} = expand('%URI{')
    assert 'path:' in entries
    assert 'query:' in entries

    assert {:yes, '', entries} = expand('%URI{path: "foo",')
    assert 'path:' not in entries
    assert 'query:' in entries

    assert {:yes, 'ry: ', []} = expand('%URI{path: "foo", que')
    assert {:no, [], []} = expand('%URI{path: "foo", unkno')
    assert {:no, [], []} = expand('%Unkown{path: "foo", unkno')
  end

  test "completion for struct var keys" do
    eval("struct = %IEx.AutocompleteTest.MyStruct{}")
    assert expand('struct.my') == {:yes, '_val', []}
  end

  test "ignore invalid Elixir module literals" do
    defmodule(:"Elixir.IEx.AutocompleteTest.Unicodé", do: nil)
    assert expand('IEx.AutocompleteTest.Unicod') == {:no, '', []}
  after
    :code.purge(:"Elixir.IEx.AutocompleteTest.Unicodé")
    :code.delete(:"Elixir.IEx.AutocompleteTest.Unicodé")
  end

  test "signature help for functions and macros" do
    assert expand('String.graphemes(') == {:yes, '', ['graphemes(string)']}
    assert expand('def ') == {:yes, '', ['def(call, expr \\\\ nil)']}

    eval("import Enum; import Protocol")

    assert ExUnit.CaptureIO.capture_io(fn ->
             send(self(), expand('reduce('))
           end) == "\nreduce(enumerable, acc, fun)"

    assert_received {:yes, '', ['reduce(enumerable, fun)']}

    assert expand('take(') == {:yes, '', ['take(enumerable, amount)']}
    assert expand('derive(') == {:yes, '', ['derive(protocol, module, options \\\\ [])']}

    defmodule NoDocs do
      def sample(a), do: a
    end

    assert {:yes, [], [_ | _]} = expand('NoDocs.sample(')
  end

  @tag :tmp_dir
  test "path completion inside strings", %{tmp_dir: dir} do
    dir |> Path.join("single1") |> File.touch()
    dir |> Path.join("file1") |> File.touch()
    dir |> Path.join("file2") |> File.touch()
    dir |> Path.join("dir") |> File.mkdir()
    dir |> Path.join("dir/file3") |> File.touch()
    dir |> Path.join("dir/file4") |> File.touch()

    assert expand('"./') == path_autocompletion(".")
    assert expand('"/') == path_autocompletion("/")
    assert expand('"./#\{') == expand('{')
    assert expand('"./#\{Str') == expand('{Str')
    assert expand('Path.join("./", is_') == expand('is_')

    assert expand('"#{dir}/') == path_autocompletion(dir)
    assert expand('"#{dir}/sin') == {:yes, 'gle1', []}
    assert expand('"#{dir}/single1') == {:yes, '"', []}
    assert expand('"#{dir}/fi') == {:yes, 'le', []}
    assert expand('"#{dir}/file') == path_autocompletion(dir, "file")
    assert expand('"#{dir}/d') == {:yes, 'ir/', []}
    assert expand('"#{dir}/dir') == {:yes, '/', []}
    assert expand('"#{dir}/dir/') == {:yes, 'file', []}
    assert expand('"#{dir}/dir/file') == dir |> Path.join("dir") |> path_autocompletion("file")
  end

  defp path_autocompletion(dir, hint \\ "") do
    dir
    |> File.ls!()
    |> Stream.filter(&String.starts_with?(&1, hint))
    |> Enum.map(&String.to_charlist/1)
    |> case do
      [] -> {:no, '', []}
      list -> {:yes, '', list}
    end
  end
end
