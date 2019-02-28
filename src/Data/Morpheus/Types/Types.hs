{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE DeriveDataTypeable, DeriveGeneric, DeriveAnyClass , TypeOperators #-}

module Data.Morpheus.Types.Types
    ( Validation
    , QuerySelection(..)
    , SelectionSet
    , (::->)(..)
    , GQLQueryRoot(..)
    , Fragment(..)
    , FragmentLib
    , GQLResponse(..)
    , GQLRequest(..)
    , Argument(..)
    , ResolveIO(..)
    , failResolveIO
    , Arguments
    , EnumOf(..)
    , GQLOperator(..)
    )
where

import           GHC.Generics                   ( Generic )
import           Data.Text                      ( Text )
import           Data.Map                       ( Map
                                                , mapKeys
                                                )
import           Data.Aeson                     ( ToJSON(..)
                                                , object
                                                , (.=)
                                                , FromJSON(..)
                                                , Value(Null)
                                                )
import           Data.Data
import           Data.Morpheus.Types.Error     ( GQLError )
import           Data.Morpheus.Types.JSType     ( JSType )
import           Control.Monad.Trans            ( liftIO
                                                , lift
                                                , MonadTrans
                                                )
import           Control.Monad                  ( forM
                                                , liftM
                                                )
import           Control.Monad.Trans.Except     ( ExceptT(..)
                                                , runExceptT
                                                )

type ResolveIO  = ExceptT [GQLError] IO

newtype EnumOf a = EnumOf { unpackEnum :: a }  deriving (Show, Generic , Data)

failResolveIO :: [GQLError] -> ResolveIO a
failResolveIO = ExceptT . pure . Left

data Argument =  Variable Text | Argument JSType deriving (Show, Generic)
type Arguments = [(Text,Argument)]

type Validation a = Either [GQLError] a

type SelectionSet  = [(Text,QuerySelection)]

data QuerySelection =
    SelectionSet Arguments SelectionSet |
    Field Arguments Text |
    Spread Text |
    QNull
    deriving (Show, Generic)

data GQLOperator = QueryOperator Text QuerySelection | MutationOperator Text QuerySelection

type FragmentLib = Map Text Fragment

data Fragment = Fragment {
    id:: Text,
    target :: Text,
    fragmentContent:: QuerySelection
} deriving (Show, Generic)

data GQLQueryRoot = GQLQueryRoot {
    fragments:: FragmentLib,
    queryBody :: GQLOperator,
    inputVariables:: Map Text JSType
}

data a ::-> b = TypeHolder (Maybe a) | Resolver (a -> ResolveIO b) | Some b | None deriving (Generic)

instance Show (a ::-> b) where
    show _ = "Inline"

instance (Data a, Data b) => Data (a ::-> b) where
    gfoldl k z _ = z None
    gunfold k z c = z None
    toConstr (Some _ ) = con_Some
    toConstr _      = con_None
    dataTypeOf _ = ty_Resolver

con_Some = mkConstr ty_Resolver "Some" [] Prefix
con_None = mkConstr ty_Resolver "None" [] Prefix
ty_Resolver = mkDataType "Module.Resolver" [con_None, con_Some]

instance FromJSON ( p ::->  o) where
    parseJSON _ =  pure None

instance (ToJSON o) => ToJSON ( p ::->  o) where
    toJSON (Some o) = toJSON o
    toJSON None = Null

data GQLResponse = Data JSType | Errors [GQLError]  deriving (Show,Generic)




instance ToJSON  GQLResponse where
  toJSON (Errors _errors) = object ["errors" .= _errors]
  toJSON (Data _data) = object ["data" .= _data]

data GQLRequest = GQLRequest {
    query:: Text
    ,operationName:: Maybe Text
    -- TODO: Make inputVariables generic JSON input
    ,variables:: Maybe (Map Text JSType)
} deriving (Show,Generic,ToJSON,FromJSON)
