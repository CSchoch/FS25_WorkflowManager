import {themes as prismThemes} from 'prism-react-renderer';
import type {Config} from '@docusaurus/types';
import type * as Preset from '@docusaurus/preset-classic';

const config: Config = {
  title: 'FS25 Workflow Manager',
  tagline: 'Automate your farm with AutoDrive and Courseplay workflows',
  favicon: 'img/favicon.ico',

  future: {
    v4: true,
  },

  // GitHub Pages deployment config
  url: 'https://cschoch.github.io',
  baseUrl: '/LS25_WorkflowManager/',

  organizationName: 'CSchoch',
  projectName: 'LS25_WorkflowManager',
  trailingSlash: false,

  onBrokenLinks: 'throw',

  i18n: {
    defaultLocale: 'en',
    locales: ['en'],
  },

  presets: [
    [
      'classic',
      {
        docs: {
          sidebarPath: './sidebars.ts',
          editUrl: 'https://github.com/CSchoch/LS25_WorkflowManager/tree/main/website/',
          routeBasePath: 'docs',
        },
        blog: false, // Disable blog
        theme: {
          customCss: './src/css/custom.css',
        },
      } satisfies Preset.Options,
    ],
  ],

  themeConfig: {
    image: 'img/social-card.png',
    colorMode: {
      defaultMode: 'dark',
      respectPrefersColorScheme: true,
    },
    navbar: {
      title: 'FS25 Workflow Manager',
      logo: {
        alt: 'Workflow Manager Logo',
        src: 'img/logo.png',
      },
      items: [
        {
          type: 'docSidebar',
          sidebarId: 'docsSidebar',
          position: 'left',
          label: 'Documentation',
        },
        {
          href: 'https://github.com/CSchoch/LS25_WorkflowManager',
          label: 'GitHub',
          position: 'right',
        },
      ],
    },
    footer: {
      style: 'dark',
      links: [
        {
          title: 'Documentation',
          items: [
            {
              label: 'Getting Started',
              to: '/docs/getting-started',
            },
            {
              label: 'Creating Workflows',
              to: '/docs/workflows/creating-workflows',
            },
            {
              label: 'API Reference',
              to: '/docs/api/autodrive',
            },
          ],
        },
        {
          title: 'Community',
          items: [
            {
              label: 'Giants Forum',
              href: 'https://forum.giants-software.com/',
            },
            {
              label: 'AutoDrive',
              href: 'https://github.com/Stephan-S/FS25_AutoDrive',
            },
            {
              label: 'Courseplay',
              href: 'https://github.com/Courseplay/Courseplay_FS25',
            },
          ],
        },
        {
          title: 'More',
          items: [
            {
              label: 'GitHub',
              href: 'https://github.com/CSchoch/LS25_WorkflowManager',
            },
            {
              label: 'Report Issues',
              href: 'https://github.com/CSchoch/LS25_WorkflowManager/issues',
            },
          ],
        },
      ],
      copyright: `Copyright © ${new Date().getFullYear()} FS25 Workflow Manager. Built with Docusaurus.`,
    },
    prism: {
      theme: prismThemes.github,
      darkTheme: prismThemes.dracula,
      additionalLanguages: ['lua', 'markup'],
    },
  } satisfies Preset.ThemeConfig,
};

export default config;
