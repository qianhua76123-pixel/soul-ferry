# UIConstants.gd
# 渡魂录全局UI常量——所有场景统一引用此文件

const COLORS = {
	"ink":      Color(0.051, 0.051, 0.051),   # #0d0d0d 墨黑
	"parch":    Color(0.102, 0.082, 0.031),   # #1a1508 泛黄纸色
	"gold":     Color(0.784, 0.663, 0.431),   # #c8a96e 旧金
	"gold_dim": Color(0.420, 0.353, 0.188),   # #6b5a30 暗金
	"ash":      Color(0.604, 0.565, 0.502),   # #9a9080 灰烬
	# 五情色
	"nu":       Color(0.753, 0.224, 0.169),   # #c0392b 怒——朱砂红
	"ju":       Color(0.424, 0.204, 0.514),   # #6c3483 惧——暗紫
	"bei":      Color(0.102, 0.322, 0.463),   # #1a5276 悲——深青
	"xi":       Color(0.718, 0.467, 0.051),   # #b7770d 喜——琥珀金
	"ding":     Color(0.114, 0.416, 0.329),   # #1d6a54 定——松绿
	# 节点类型色
	"battle":   Color(0.482, 0.102, 0.102),   # #7b1a1a
	"shop":     Color(0.353, 0.290, 0.0),     # #5a4a00
	"event":    Color(0.102, 0.227, 0.102),   # #1a3a1a
	"rest":     Color(0.102, 0.165, 0.227),   # #1a2a3a
	"boss":     Color(0.239, 0.0,   0.0),     # #3d0000
}

const EMOTION_COLORS = {
	"rage":  Color(0.753, 0.224, 0.169),
	"fear":  Color(0.424, 0.204, 0.514),
	"grief": Color(0.102, 0.322, 0.463),
	"joy":   Color(0.718, 0.467, 0.051),
	"calm":  Color(0.114, 0.416, 0.329),
}

const FONT_SIZES = {
	"title":   32,
	"heading": 18,
	"body":    13,
	"caption": 11,
	"micro":   10,
}
