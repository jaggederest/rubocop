# frozen_string_literal: true

describe RuboCop::Cop::Lint::UnusedMethodArgument, :config do
  subject(:cop) { described_class.new(config) }
  let(:cop_config) do
    { 'AllowUnusedKeywordArguments' => false, 'IgnoreEmptyMethods' => false }
  end

  describe 'inspection' do
    before do
      inspect_source(source)
    end

    context 'when a method takes multiple arguments' do
      context 'and an argument is unused' do
        let(:source) { <<-RUBY }
          def some_method(foo, bar)
            puts bar
          end
        RUBY

        it 'registers an offense' do
          expect(cop.offenses.size).to eq(1)
          expect(cop.offenses.first.message).to eq(
            'Unused method argument - `foo`. ' \
            "If it's necessary, use `_` or `_foo` " \
            "as an argument name to indicate that it won't be used."
          )
          expect(cop.offenses.first.severity.name).to eq(:warning)
          expect(cop.offenses.first.line).to eq(1)
          expect(cop.highlights).to eq(['foo'])
        end

        context 'and arguments are swap-assigned' do
          let(:source) { <<-RUBY }
            def foo(a, b)
              a, b = b, a
            end
          RUBY

          it 'accepts' do
            expect_no_offenses(source)
          end
        end

        context "and one argument is assigned to another, whilst other's " \
                  'value is not used' do
          let(:source) { <<-RUBY }
            def foo(a, b)
              a, b = b, 42
            end
          RUBY

          it 'registers an offense' do
            expect(cop.offenses.size).to eq(1)
            expect(cop.offenses.first.message).to eq(
              'Unused method argument - `a`. ' \
                "If it's necessary, use `_` or `_a` as an argument name " \
                "to indicate that it won't be used."
            )
            expect(cop.offenses.first.severity.name).to eq(:warning)
            expect(cop.offenses.first.line).to eq(1)
            expect(cop.highlights).to eq(['a'])
          end
        end
      end

      context 'and all the arguments are unused' do
        let(:source) { <<-RUBY }
          def some_method(foo, bar)
          end
        RUBY

        it 'registers offenses and suggests the use of `*`' do
          expect(cop.offenses.size).to eq(2)
          expect(cop.offenses.first.message).to eq(
            'Unused method argument - `foo`. ' \
            "If it's necessary, use `_` or `_foo` " \
            "as an argument name to indicate that it won't be used. " \
            'You can also write as `some_method(*)` if you want the method ' \
            "to accept any arguments but don't care about them."
          )
        end
      end
    end

    context 'when a required keyword argument is unused', ruby: 2.1 do
      let(:source) { <<-RUBY }
        def self.some_method(foo, bar:)
          puts foo
        end
      RUBY

      it 'registers an offense but does not suggest underscore-prefix' do
        expect(cop.offenses.size).to eq(1)
        expect(cop.highlights).to eq(['bar'])
        expect(cop.offenses.first.message)
          .to eq('Unused method argument - `bar`.')
      end
    end

    context 'when an optional keyword argument is unused' do
      let(:source) { <<-RUBY }
        def self.some_method(foo, bar: 1)
          puts foo
        end
      RUBY

      it 'registers an offense but does not suggest underscore-prefix' do
        expect(cop.offenses.size).to eq(1)
        expect(cop.highlights).to eq(['bar'])
        expect(cop.offenses.first.message)
          .to eq('Unused method argument - `bar`.')
      end

      context 'and AllowUnusedKeywordArguments set' do
        let(:cop_config) { { 'AllowUnusedKeywordArguments' => true } }

        it 'does not care' do
          expect_no_offenses(<<-RUBY.strip_indent)
            def self.some_method(foo, bar: 1)
              puts foo
            end
          RUBY
        end
      end
    end

    context 'when a singleton method argument is unused' do
      let(:source) { <<-RUBY }
        def self.some_method(foo)
        end
      RUBY

      it 'registers an offense' do
        expect(cop.offenses.size).to eq(1)
        expect(cop.offenses.first.line).to eq(1)
        expect(cop.highlights).to eq(['foo'])
      end
    end

    context 'when an underscore-prefixed method argument is unused' do
      let(:source) { <<-RUBY }
        def some_method(_foo)
        end
      RUBY

      it 'accepts' do
        expect_no_offenses(<<-RUBY.strip_indent)
          def some_method(_foo)
          end
        RUBY
      end
    end

    context 'when a method argument is used' do
      let(:source) { <<-RUBY }
        def some_method(foo)
          puts foo
        end
      RUBY

      it 'accepts' do
        expect_no_offenses(<<-RUBY.strip_indent)
          def some_method(foo)
            puts foo
          end
        RUBY
      end
    end

    context 'when a method argument is reassigned' do
      context 'and the argument was reassigned in the conditional' do
        let(:source) { <<-RUBY.strip_indent }
          def some_method(foo)
            foo = 42 if bar
            puts foo
          end
        RUBY

        it 'accepts' do
          expect_no_offenses(source)
        end

        context 'and was not used after the reassignment' do
          let(:source) { <<-RUBY.strip_indent }
            def some_method(foo)
              foo = 42 if bar
              puts bar
            end
          RUBY

          it 'registers an offense' do
            expect(cop.offenses.size).to eq(1)
          end
        end
      end

      context 'and the argument used at the assignment' do
        let(:source) { <<-RUBY.strip_indent }
          def some_method(foo)
            foo = foo + 42
            puts foo
          end
        RUBY

        it 'accepts' do
          expect_no_offenses(source)
        end
      end

      context 'and the argument is not used at the assignment' do
        context 'and the argument was not used before the assignment' do
          let(:source) { <<-RUBY.strip_indent }
            def some_method(foo)
              puts 'bar'
              foo = 42
              puts foo
            end
          RUBY

          it 'registers an offense' do
            expect(cop.offenses.size).to eq(1)
          end
        end

        context 'and the argument was used before the assignment' do
          let(:source) { <<-RUBY.strip_indent }
            def some_method(foo)
              puts foo
              foo = 42
              puts foo
            end
          RUBY

          it 'accepts' do
            expect_no_offenses(source)
          end
        end
      end
    end

    context 'when a variable is unused' do
      let(:source) { <<-RUBY }
        def some_method
          foo = 1
        end
      RUBY

      it 'does not care' do
        expect_no_offenses(<<-RUBY.strip_indent)
          def some_method
            foo = 1
          end
        RUBY
      end
    end

    context 'when a block argument is unused' do
      let(:source) { <<-RUBY }
        1.times do |foo|
        end
      RUBY

      it 'does not care' do
        expect_no_offenses(<<-RUBY.strip_indent)
          1.times do |foo|
          end
        RUBY
      end
    end

    context 'in a method calling `super` without arguments' do
      context 'when a method argument is not used explicitly' do
        let(:source) { <<-RUBY }
          def some_method(foo)
            super
          end
        RUBY

        it 'accepts since the arguments are guaranteed to be the same as ' \
           "superclass' ones and the user has no control on them" do
          expect(cop.offenses).to be_empty
        end
      end
    end

    context 'in a method calling `super` with arguments' do
      context 'when a method argument is unused' do
        let(:source) { <<-RUBY }
          def some_method(foo)
            super(:something)
          end
        RUBY

        it 'registers an offense' do
          expect(cop.offenses.size).to eq(1)
          expect(cop.offenses.first.line).to eq(1)
          expect(cop.highlights).to eq(['foo'])
        end
      end
    end

    context 'in a method calling `binding` without arguments' do
      let(:source) { <<-RUBY }
        def some_method(foo, bar)
          do_something binding
        end
      RUBY

      it 'accepts all arguments' do
        expect_no_offenses(<<-RUBY.strip_indent)
          def some_method(foo, bar)
            do_something binding
          end
        RUBY
      end

      context 'inside another method definition' do
        let(:source) { <<-RUBY }
          def some_method(foo, bar)
            def other(a)
              puts something(binding)
            end
          end
        RUBY

        it 'registers offenses' do
          expect(cop.offenses.size).to eq 2
          expect(cop.offenses.first.line).to eq(1)
          expect(cop.highlights).to eq(%w[foo bar])
        end
      end
    end

    context 'in a method calling `binding` with arguments' do
      context 'when a method argument is unused' do
        let(:source) { <<-RUBY }
          def some_method(foo)
            binding(:something)
          end
        RUBY

        it 'registers an offense' do
          expect(cop.offenses.size).to eq(1)
          expect(cop.offenses.first.line).to eq(1)
          expect(cop.highlights).to eq(['foo'])
        end
      end
    end
  end

  describe 'auto-correction' do
    let(:corrected_source) { autocorrect_source(source) }

    context 'when multiple arguments are unused' do
      let(:source) { <<-RUBY }
        def some_method(foo, bar)
        end
      RUBY

      let(:expected_source) { <<-RUBY }
        def some_method(_foo, _bar)
        end
      RUBY

      it 'adds underscore-prefix to them' do
        expect(corrected_source).to eq(expected_source)
      end
    end

    context 'when only a part of arguments is unused' do
      let(:source) { <<-RUBY }
        def some_method(foo, bar)
          puts foo
        end
      RUBY

      let(:expected_source) { <<-RUBY }
        def some_method(foo, _bar)
          puts foo
        end
      RUBY

      it 'modifies only the unused one' do
        expect(corrected_source).to eq(expected_source)
      end
    end

    context 'when there is some whitespace around the argument' do
      let(:source) { <<-RUBY }
        def some_method(foo,
            bar)
          puts foo
        end
      RUBY

      let(:expected_source) { <<-RUBY }
        def some_method(foo,
            _bar)
          puts foo
        end
      RUBY

      it 'preserves the whitespace' do
        expect(corrected_source).to eq(expected_source)
      end
    end

    context 'when a splat argument is unused' do
      let(:source) { <<-RUBY }
        def some_method(foo, *bar)
          puts foo
        end
      RUBY

      let(:expected_source) { <<-RUBY }
        def some_method(foo, *_bar)
          puts foo
        end
      RUBY

      it 'preserves the splat' do
        expect(corrected_source).to eq(expected_source)
      end
    end

    context 'when an unused argument has default value' do
      let(:source) { <<-RUBY }
        def some_method(foo, bar = 1)
          puts foo
        end
      RUBY

      let(:expected_source) { <<-RUBY }
        def some_method(foo, _bar = 1)
          puts foo
        end
      RUBY

      it 'preserves the default value' do
        expect(corrected_source).to eq(expected_source)
      end
    end

    context 'when a keyword argument is unused' do
      let(:source) { <<-RUBY }
        def some_method(foo, bar: 1)
          puts foo
        end
      RUBY

      it 'ignores that since modifying the name changes the method interface' do
        expect(corrected_source).to eq(source)
      end
    end

    context 'when a trailing block argument is unused' do
      let(:source) { <<-RUBY }
        def some_method(foo, bar, &block)
          foo + bar
        end
      RUBY

      let(:expected_source) { <<-RUBY }
        def some_method(foo, bar)
          foo + bar
        end
      RUBY

      it 'removes the unused block arg' do
        expect(corrected_source).to eq(expected_source)
      end
    end
  end

  context 'when IgnoreEmptyMethods config parameter is set' do
    let(:cop_config) { { 'IgnoreEmptyMethods' => true } }

    it 'accepts an empty method with a single unused parameter' do
      expect_no_offenses(<<-RUBY.strip_indent)
        def method(arg)
        end
      RUBY
    end

    it 'registers an offense for a non-empty method with a single unused ' \
        'parameter' do
      inspect_source(<<-RUBY.strip_indent)
        def method(arg)
          1
        end
      RUBY
      expect(cop.offenses.size).to eq 1
    end

    it 'accepts an empty method with multiple unused parameters' do
      expect_no_offenses(<<-RUBY.strip_indent)
        def method(a, b, *others)
        end
      RUBY
    end

    it 'registers an offense for a non-empty method with multiple unused ' \
       'parameters' do
      inspect_source(<<-RUBY.strip_indent)
        def method(a, b, *others)
          1
        end
      RUBY
      expect(cop.offenses.size).to eq 3
    end
  end
end
