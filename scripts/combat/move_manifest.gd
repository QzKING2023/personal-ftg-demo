class_name MoveManifest
extends Resource
## 招式表清单：统一引用每招一个的类型化 MoveData 资源。
## 稳定 id 是资源自身的身份（MoveData.move_id），不由文件名推断；
## 训练场与 Combo Solver 都只通过 MoveTable 读取这一份清单。

## 招式资源路径列表（按此顺序枚举，保证运行时与 Solver 的确定性一致）。
@export var move_paths: Array[String] = []
