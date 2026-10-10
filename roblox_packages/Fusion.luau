local module = require(script.Parent:FindFirstChild(".pesde"):FindFirstChild("elttob_fusion@0.2.0"):FindFirstChild("fusion"))
export type StateObject<T> = module.StateObject<T>
export type CanBeState<T> = module.CanBeState<T>
export type Symbol  = module.Symbol 
export type Value<T> = module.Value<T>
export type Computed<T> = module.Computed<T>
export type ForPairs<KO, VO> = module.ForPairs<KO, VO>
export type ForKeys<KI, KO> = module.ForKeys<KI, KO>
export type ForValues<VI, VO> = module.ForValues<VI, VO>
export type Observer  = module.Observer 
export type Tween<T> = module.Tween<T>
export type Spring<T> = module.Spring<T>
return module