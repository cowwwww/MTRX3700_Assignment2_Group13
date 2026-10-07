// No recorded vowel captures were supplied yet. All classes stay disabled.
// Run tools/train_saved_templates.py with ee, ah, oo and aw feature CSVs.
localparam bit TEMPLATES_READY = 0;
localparam int TEMPLATE_D = 24;
localparam int TEMPLATE_NT = 4;
localparam logic [23:0][15:0] TEMPLATES [0:15] = '{default:'0};
