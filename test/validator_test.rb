require "test_helper"

class ValidatorTest < Test::Unit::TestCase
  include TestHelper

  Environment = RBS::Environment
  Namespace = RBS::Namespace
  InvalidTypeApplicationError = RBS::InvalidTypeApplicationError

  def test_validate
    SignatureManager.new do |manager|
      manager.add_file("foo.rbs", <<-EOF)
class Array[A]
end

class String::Foo
end

class Foo
end

type Foo::Bar::Baz::t = Integer

type ty = String | Integer
      EOF

      manager.build do |env|
        root = [Namespace.root]

        resolver = RBS::TypeNameResolver.from_env(env)
        validator = RBS::Validator.new(env: env, resolver: resolver)

        validator.validate_type(parse_type("::Foo"), context: root)
        validator.validate_type(parse_type("::String::Foo"), context: root)

        validator.validate_type(parse_type("Array[String]"), context: root)

        assert_raises InvalidTypeApplicationError do
          validator.validate_type(parse_type("Array"), context: root)
        end

        assert_raises InvalidTypeApplicationError do
          validator.validate_type(parse_type("Array[1,2,3]"), context: root)
        end

        validator.validate_type(parse_type("::ty"), context: root)

        assert_raises RBS::NoTypeFoundError do
          validator.validate_type(parse_type("::ty2"), context: root)
        end

        assert_raises RBS::NoTypeFoundError do
          validator.validate_type(parse_type("catcat"), context: root)
        end

        assert_raises RBS::NoTypeFoundError do
          validator.validate_type(parse_type("::_NoSuchInterface"), context: root)
        end
      end
    end
  end

  def test_validate_recursive_type_alias
    SignatureManager.new do |manager|
      manager.add_file("bar.rbs", <<-EOF)
type x = x
type random = Float & Integer & random
type something = String | something | Integer

type x_1 = y
type y = z
type z = x_1

type test = test?

type i = String | Integer | i_1
type i_1 = Float | i_2 | String
type i_2 = string | i | Numeric

type u = String & Integer & u_1
type u_1 = Float & u_2 | String
type u_2 = string & u & Numeric
      EOF

      manager.build do |env|
        resolver = RBS::TypeNameResolver.from_env(env)
        validator = RBS::Validator.new(env: env, resolver: resolver)
        env.alias_decls.each do |name, decl|
          assert_raises RBS::RecursiveTypeAliasError do
            validator.validate_type_alias(entry: decl)
          end
        end
      end
    end
  end

  def test_recursive_type_aliases
    SignatureManager.new do |manager|
      manager.add_file("test.rbs", <<-EOF)
type x_2 = [x_2, x_2]
type test_1 = Array[Hash[test_1, String]]
class Bar
 type test_2 = Array[Hash[Integer, Hash[Integer, Bar::test_2]]]
end
type proc = ^(proc) -> proc
type record = { foo: record }
      EOF
      manager.build do |env|
        resolver = RBS::TypeNameResolver.from_env(env)
        validator = RBS::Validator.new(env: env, resolver: resolver)

        env.alias_decls.each do |name, entry|
          assert_nil validator.validate_type_alias(entry: entry)
        end
      end
    end
  end
end
