// Como a sidebar renderiza links: o pai injeta o <Link> do roteador; sem ele cai num <a href> comum.
import { createContext, useContext, type AnchorHTMLAttributes, type ReactNode } from 'react'

export type SidebarLinkProps = Omit<AnchorHTMLAttributes<HTMLAnchorElement>, 'href'> & {
  to: string
  children?: ReactNode
}

export type LinkRenderer = (props: SidebarLinkProps) => ReactNode

const defaultRenderer: LinkRenderer = ({ to, children, ...rest }) => (
  <a href={to} {...rest}>
    {children}
  </a>
)

const LinkContext = createContext<LinkRenderer>(defaultRenderer)

export const LinkProvider = LinkContext.Provider

export function SidebarLink(props: SidebarLinkProps) {
  return <>{useContext(LinkContext)(props)}</>
}
