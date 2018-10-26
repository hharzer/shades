// TypeScript Version: 2.9

// prettier-ignore
export type Functor<F, A, B> =
  F extends A[] ? B[] :
  F extends { [key: string]: A } ? { [key: string]: B } :
  never;

// prettier-ignore
export type KeyedFunctor<K extends string, F> =
  F extends Array<{ [_ in K]: any }> ? Array<F[number][K]> :
  F extends { [key: string]: { [_ in K]: any } } ? { [key: string]: F[string][K] } :
  never;

// prettier-ignore
export type IndexFunctor<F> =
  F extends Array<Array<infer A>> ? A[] :
  F extends { [n: string]: Array<infer A> } ? { [key: string]: A } :
  never;

type Unpack<F> = F extends (infer A)[]
  ? A
  : F extends Record<string, infer A>
    ? A
    : F extends { [n: number]: infer A }
      ? A
      : F extends Record<symbol, infer A> ? A : never;

type HasKey<K extends string> = { [_ in K]: any };

export type Contains<K extends string> =
  | Array<HasKey<K>>
  | { [key: string]: HasKey<K> };