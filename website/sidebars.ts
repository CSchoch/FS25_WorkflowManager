import type {SidebarsConfig} from '@docusaurus/plugin-content-docs';

const sidebars: SidebarsConfig = {
  docsSidebar: [
    'intro',
    'getting-started',
    'installation',
    {
      type: 'category',
      label: 'Workflows',
      items: [
        'workflows/creating-workflows',
        'workflows/step-types',
        'workflows/executing-workflows',
        'workflows/linked-workflows',
      ],
    },
    {
      type: 'category',
      label: 'User Interface',
      items: [
        'ui/main-dialog',
        'ui/editor-dialog',
        'ui/hud-controls',
      ],
    },
    {
      type: 'category',
      label: 'Reference',
      items: [
        'api/autodrive',
        'api/courseplay',
        'api/xml-format',
      ],
    },
    'faq',
    'troubleshooting',
  ],
};

export default sidebars;
